package com.example.timeflow

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "timeflow/usage"
    private var launchableCache: Set<String>? = null
    private var homeCache: Set<String>? = null
    private val iconCache = HashMap<String, ByteArray>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }
                    "fetchSessions" -> {
                        val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
                        val endMs = call.argument<Number>("endMs")?.toLong()
                            ?: System.currentTimeMillis()
                        try {
                            result.success(fetchSessions(startMs, endMs))
                        } catch (t: Throwable) {
                            result.error("fetch_failed", t.message ?: "unknown", null)
                        }
                    }
                    "getAppIcon" -> {
                        val pkg = call.argument<String>("appId")
                        if (pkg.isNullOrEmpty()) {
                            result.success(null)
                        } else {
                            result.success(appIcon(pkg))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun appIcon(pkg: String): ByteArray? {
        iconCache[pkg]?.let { return it }
        return try {
            val drawable = packageManager.getApplicationIcon(pkg)
            val size = 128
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            val bytes = out.toByteArray()
            iconCache[pkg] = bytes
            bytes
        } catch (_: Exception) {
            null
        }
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (_: Exception) {
            startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    private fun labelFor(pkg: String): String {
        return try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            pkg
        }
    }

    /**
     * Reconstructs foreground sessions from UsageEvents. We start scanning a
     * little before the requested day so an app that was already open at
     * midnight is still counted correctly.
     */
    private fun fetchSessions(startMs: Long, endMs: Long): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val scanStart = (startMs - 12L * 60L * 60L * 1000L).coerceAtLeast(0L)
        val events = usm.queryEvents(scanStart, endMs)
        val results = ArrayList<Map<String, Any>>(64)
        if (events == null) return results

        val event = UsageEvents.Event()
        var currentPkg: String? = null
        var currentStart = 0L
        val labels = HashMap<String, String>()
        val launchable = launchablePackages()
        val ignored = ignoredPackages()

        fun flush(end: Long) {
            val pkg = currentPkg ?: return
            val safeStart = currentStart.coerceAtLeast(startMs)
            val safeEnd = end.coerceIn(startMs, endMs)
            if (safeEnd - safeStart >= 1000L) {
                results.add(
                    mapOf(
                        "appId" to pkg,
                        "appName" to labels.getOrPut(pkg) { labelFor(pkg) },
                        "startMs" to safeStart,
                        "endMs" to safeEnd
                    )
                )
            }
            currentPkg = null
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (ignored.contains(pkg) || !launchable.contains(pkg)) {
                        // Another (system/launcher/non-launchable) window took
                        // the foreground. End the current app time here,
                        // otherwise home-screen or system UI time is wrongly
                        // attributed to the previous app.
                        if (currentPkg != null) flush(event.timeStamp)
                        continue
                    }
                    if (currentPkg != null && currentPkg != pkg) {
                        flush(event.timeStamp)
                    }
                    if (currentPkg == null) {
                        currentStart = event.timeStamp
                    }
                    currentPkg = pkg
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (currentPkg == pkg) flush(event.timeStamp)
                }

                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN,
                UsageEvents.Event.DEVICE_SHUTDOWN -> {
                    flush(event.timeStamp)
                }
            }
        }
        flush(endMs)
        return results
    }

    private fun ignoredPackages(): Set<String> {
        val ignored = HashSet<String>()
        ignored.add("android")
        ignored.add("com.android.systemui")
        ignored.add(packageName)
        ignored.add("com.android.permissioncontroller")
        ignored.add("com.google.android.permissioncontroller")
        ignored.addAll(homePackages())
        return ignored
    }

    /**
     * Only launchable apps are shown in the stats. This filters out launchers,
     * Play services and other background/system components that would
     * otherwise expose raw package names in the UI.
     */
    private fun launchablePackages(): Set<String> {
        launchableCache?.let { return it }
        val intent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
        val packages = queryActivities(intent)
            .mapNotNull { it.activityInfo?.packageName }
            .toHashSet()
        launchableCache = packages
        return packages
    }

    private fun homePackages(): Set<String> {
        homeCache?.let { return it }
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.resolveActivity(
                intent,
                PackageManager.ResolveInfoFlags.of(
                    PackageManager.MATCH_DEFAULT_ONLY.toLong()
                )
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        val packages = HashSet<String>()
        resolved?.activityInfo?.packageName?.let { packages.add(it) }
        homeCache = packages
        return packages
    }

    private fun queryActivities(intent: Intent): List<android.content.pm.ResolveInfo> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(
                    PackageManager.MATCH_ALL.toLong()
                )
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        }
    }
}
