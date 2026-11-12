import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

enum TrackerKind { android, windows, unsupported }

/// A snapshot of the current foreground window on desktop.
class ForegroundApp {
  const ForegroundApp({
    required this.id,
    required this.name,
    this.title,
    this.path,
    this.idleSeconds = 0,
  });

  final String id;
  final String name;
  final String? title;
  final String? path;
  final int idleSeconds;
}

/// Bridge to the small native helpers that read OS screen-time data.
///
/// * Android uses `UsageStatsManager` (history is available even when TimeFlow
///   was not running).
/// * Windows polls the foreground window and records sessions while TimeFlow is
///   running.
/// * Every other platform falls back to demo mode in the UI layer.
class UsageTracker {
  UsageTracker._(this.kind);

  static const MethodChannel _channel = MethodChannel('timeflow/usage');

  final TrackerKind kind;

  factory UsageTracker.detect() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return UsageTracker._(TrackerKind.android);
      case TargetPlatform.windows:
        return UsageTracker._(TrackerKind.windows);
      default:
        return UsageTracker._(TrackerKind.unsupported);
    }
  }

  bool get canReadHistory => kind == TrackerKind.android;
  bool get canTrackLive => kind == TrackerKind.windows;
  bool get isSupported => canReadHistory || canTrackLive;

  String get platformName {
    switch (kind) {
      case TrackerKind.android:
        return 'Android';
      case TrackerKind.windows:
        return 'Windows';
      case TrackerKind.unsupported:
        return defaultTargetPlatform.name;
    }
  }

  Future<bool> hasPermission() async {
    if (!canReadHistory) return true;
    try {
      final bool? allowed = await _channel.invokeMethod<bool>('hasUsageAccess');
      return allowed ?? false;
    } on PlatformException catch (error) {
      debugPrint('hasUsageAccess failed: ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    if (!canReadHistory) return;
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } on PlatformException catch (error) {
      debugPrint('openUsageAccessSettings failed: ${error.message}');
    } on MissingPluginException {
      // No native side registered (e.g. running in a test).
    }
  }

  /// Fetches all foreground sessions that intersect [day] (local time).
  Future<List<AppSession>> fetchSessions(DateTime day) async {
    if (!canReadHistory) return const <AppSession>[];
    final DateTime start = dateOnly(day);
    final DateTime end = DateTime(start.year, start.month, start.day + 1);
    try {
      final List<Object?>? raw = await _channel.invokeMethod<List<Object?>>(
        'fetchSessions',
        <String, int>{
          'startMs': start.millisecondsSinceEpoch,
          'endMs': end.millisecondsSinceEpoch,
        },
      );
      if (raw == null) return const <AppSession>[];
      final List<AppSession> sessions = <AppSession>[];
      for (final Object? item in raw) {
        if (item is! Map) continue;
        final Object? id = item['appId'];
        final Object? name = item['appName'];
        final Object? from = item['startMs'];
        final Object? to = item['endMs'];
        if (id is! String || from is! num || to is! num) continue;
        final int startMs = from.toInt();
        final int endMs = to.toInt();
        if (endMs <= startMs) continue;
        sessions.add(
          AppSession(
            appId: id,
            appName: name is String && name.isNotEmpty ? name : id,
            startMs: startMs,
            endMs: endMs,
          ),
        );
      }
      return normalizeSessions(sessions);
    } on PlatformException catch (error) {
      debugPrint('fetchSessions failed: ${error.message}');
      return const <AppSession>[];
    } on MissingPluginException {
      return const <AppSession>[];
    }
  }

  Future<ForegroundApp?> foregroundApp() async {
    if (!canTrackLive) return null;
    try {
      final Map<Object?, Object?>? raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('fetchForegroundApp');
      if (raw == null) return null;
      final Object? id = raw['appId'];
      final Object? name = raw['appName'];
      final Object? title = raw['windowTitle'];
      final Object? path = raw['appPath'];
      final Object? idle = raw['idleSeconds'];
      if (id is! String || id.isEmpty) return null;
      return ForegroundApp(
        id: id,
        name: name is String && name.isNotEmpty ? name : id,
        title: title is String ? title : null,
        path: path is String && path.isNotEmpty ? path : null,
        idleSeconds: idle is num ? idle.toInt() : 0,
      );
    } on PlatformException catch (error) {
      debugPrint('fetchForegroundApp failed: ${error.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
