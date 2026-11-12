import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_icons.dart';
import '../data/backup.dart';
import '../data/demo_data.dart';
import '../data/local_storage.dart';
import '../data/models.dart';
import '../data/notifications.dart';
import '../data/usage_store.dart';
import '../data/usage_tracker.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_settings.dart';

/// Single source of truth for data, sync state and preferences.
///
/// The widget layer listens with [ListenableBuilder], so a live-tracking tick
/// only repaints the screens that are actually visible.
class TimeFlowState extends ChangeNotifier with WidgetsBindingObserver {
  TimeFlowState({
    UsageTracker? tracker,
    UsagePersistence? persistence,
    SettingsPersistence? settingsPersistence,
  }) : tracker = tracker ?? UsageTracker.detect(),
       persistence = persistence ?? UsagePersistence(),
       settingsPersistence = settingsPersistence ?? SettingsPersistence();

  final UsageTracker tracker;
  final UsagePersistence persistence;
  final SettingsPersistence settingsPersistence;
  final UsageStore store = UsageStore();
  final AppSettings settings = AppSettings();

  /// Bumped when visual preferences change; the [MaterialApp] listens to this
  /// instead of the whole state so live data never rebuilds the theme.
  final ValueNotifier<int> themeRevision = ValueNotifier<int>(0);

  bool initialized = false;
  bool syncing = false;
  bool permissionGranted = false;
  bool liveTracking = false;
  bool demoActive = false;
  String? syncError;

  int syncDone = 0;
  int syncTotal = 0;

  DateTime now = DateTime.now();

  Timer? _timeTimer;
  Timer? _liveTimer;
  Timer? _flushTimer;
  Timer? _saveSettingsTimer;
  DateTime? _lastTodayFetch;
  DateTime? _demoLoadDate;
  DateTime? _lastNotificationDay;

  String? _liveAppId;
  String? _liveAppName;
  int? _liveStartMs;
  int _liveTicks = 0;

  final Set<String> _dirtyDays = <String>{}; // day keys waiting to be persisted
  Future<void>? _flushFuture;
  bool _disposed = false;

  /// Incremented whenever the whole data set is replaced (clear / demo toggle)
  /// so an in-flight sync cannot write stale days back into the store.
  int _dataEpoch = 0;

  double get syncProgress {
    if (syncTotal <= 0) return 0;
    return (syncDone / syncTotal).clamp(0.0, 1.0);
  }

  int get historyCutoffMs => settings.historyCutoffMs ?? 0;

  bool get canRestoreHistory =>
      tracker.canReadHistory &&
      permissionGranted &&
      !demoActive &&
      historyCutoffMs > 0;

  bool get isDemo => demoActive;

  DateTime get todayDate => dateOnly(now);

  DateTime? get lastSyncAt {
    final int? ms = settings.lastSyncMs;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  String? get lastSyncLabel {
    final DateTime? date = lastSyncAt;
    if (date == null) return null;
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return '${diff.inDays} дн назад';
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    settings.fromJson(await settingsPersistence.load());
    for (final MapEntry<String, String> entry in settings.appPaths.entries) {
      AppIcons.registerPath(entry.key, entry.value);
    }

    final Map<String, List<AppSession>> stored = await persistence.loadAll();
    _sanitizeDays(stored);
    store.replaceAll(stored);

    demoActive = !tracker.isSupported || settings.demoMode;
    if (demoActive) {
      _loadDemo();
    }

    if (tracker.isSupported) {
      permissionGranted = await tracker.hasPermission();
      if (permissionGranted && tracker.canTrackLive) {
        _startLiveTracking();
      }
    } else {
      permissionGranted = false;
    }

    _startTimers();
    initialized = true;
    notifyListeners();

    if (tracker.canReadHistory && permissionGranted && !demoActive) {
      unawaited(syncHistory(days: 90));
    }
    unawaited(refreshNotificationSchedule(force: true));
  }

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (settings.themeMode == mode) return;
    settings.themeMode = mode;
    themeRevision.value++;
    _scheduleSettingsSave();
  }

  Future<void> setFontId(String id) async {
    if (settings.fontId == id) return;
    settings.fontId = id;
    themeRevision.value++;
    _scheduleSettingsSave();
  }

  Future<void> setPalette(int index) async {
    if (settings.paletteIndex == index) return;
    settings.paletteIndex = index;
    themeRevision.value++;
    _scheduleSettingsSave();
  }

  // ---------------------------------------------------------------------------
  // Daily notifications
  // ---------------------------------------------------------------------------

  String get _notificationBody {
    if (demoActive) {
      return 'Открой TimeFlow, чтобы посмотреть статистику экранного времени.';
    }
    final DaySummary summary = store.summaryFor(addDays(todayDate, -1));
    if (summary.isEmpty) {
      return 'Вчера не было записано активности.';
    }
    final AppUsage? top = summary.topApp;
    final String topPart = top == null
        ? ''
        : ' Больше всего — ${top.appName} (${formatPercent(top.shareOf(summary.total))}).';
    return 'Вчера: ${formatDuration(summary.total)} экранного времени.$topPart';
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      final bool allowed = await DailyNotifications.requestPermission();
      if (!allowed) {
        settings.notificationsEnabled = false;
        _scheduleSettingsSave();
        if (!_disposed) notifyListeners();
        return false;
      }
    }
    settings.notificationsEnabled = enabled;
    _lastNotificationDay = null;
    _scheduleSettingsSave();
    await refreshNotificationSchedule(force: true);
    if (!_disposed) notifyListeners();
    return true;
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    settings.notificationHour = time.hour;
    settings.notificationMinute = time.minute;
    _lastNotificationDay = null;
    _scheduleSettingsSave();
    await refreshNotificationSchedule(force: true);
    if (!_disposed) notifyListeners();
  }

  Future<void> showTestNotification() async {
    await DailyNotifications.showTest(
      title: 'TimeFlow',
      body: _notificationBody,
    );
  }

  Future<void> refreshNotificationSchedule({bool force = false}) async {
    if (_disposed) return;
    final DateTime today = todayDate;
    if (!force &&
        _lastNotificationDay != null &&
        isSameDay(_lastNotificationDay!, today)) {
      return;
    }
    _lastNotificationDay = today;
    await DailyNotifications.schedule(
      enabled: settings.notificationsEnabled,
      hour: settings.notificationHour,
      minute: settings.notificationMinute,
      title: 'TimeFlow · итоги дня',
      body: _notificationBody,
    );
  }

  // ---------------------------------------------------------------------------
  // Local backup
  // ---------------------------------------------------------------------------

  String createBackup() {
    return TimeFlowBackup.encode(
      days: store.rawDays,
      themeIndex: settings.themeMode.index,
      paletteIndex: settings.paletteIndex,
    );
  }

  Future<BackupImportResult> importBackup(
    String payload, {
    required bool replace,
  }) async {
    final BackupPayload backup = TimeFlowBackup.parse(payload);
    _dataEpoch++;
    for (int i = 0; i < 50 && syncing && !_disposed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_disposed) {
      return const BackupImportResult(
        dayCount: 0,
        sessionCount: 0,
        replaced: false,
      );
    }

    final bool effectiveReplace = replace || demoActive;
    final bool wasDemo = demoActive;
    final Map<String, List<AppSession>> merged = <String, List<AppSession>>{};
    if (!effectiveReplace) {
      for (final MapEntry<String, List<AppSession>> entry
          in store.rawDays.entries) {
        merged[entry.key] = List<AppSession>.of(entry.value);
      }
    }
    for (final MapEntry<String, List<AppSession>> entry
        in backup.days.entries) {
      merged.putIfAbsent(entry.key, () => <AppSession>[]).addAll(entry.value);
    }
    for (final String key in merged.keys.toList()) {
      final List<AppSession> cleaned = merged[key]!
          .where((AppSession session) => !_isSelfSession(session))
          .toList();
      if (cleaned.isEmpty) {
        merged.remove(key);
      } else {
        merged[key] = cleaned;
      }
    }

    if (effectiveReplace) {
      store.clear();
      await persistence.clear();
      if (_disposed) {
        return const BackupImportResult(
          dayCount: 0,
          sessionCount: 0,
          replaced: true,
        );
      }
    }
    store.replaceAll(merged);
    if (wasDemo) {
      demoActive = false;
      settings.demoMode = false;
    }
    _dirtyDays.clear();
    _dirtyDays.addAll(store.rawDays.keys);
    await _flushDirty();

    settings.historyCutoffMs = null;
    settings.lastSyncMs = null;
    _lastTodayFetch = null;
    final int? themeIndex = backup.themeIndex;
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < AppThemeMode.values.length) {
      settings.themeMode = AppThemeMode.values[themeIndex];
    }
    final int? paletteIndex = backup.paletteIndex;
    if (paletteIndex != null) {
      settings.paletteIndex = paletteIndex.clamp(0, kPalettes.length - 1);
    }
    if (wasDemo && tracker.canTrackLive && permissionGranted) {
      _startLiveTracking();
    }
    _scheduleSettingsSave();
    themeRevision.value++;
    _lastNotificationDay = null;
    if (!_disposed) notifyListeners();
    unawaited(refreshNotificationSchedule(force: true));

    return BackupImportResult(
      dayCount: store.dayCount,
      sessionCount: store.rawDays.values.fold<int>(
        0,
        (int sum, List<AppSession> sessions) => sum + sessions.length,
      ),
      replaced: effectiveReplace,
    );
  }

  Future<void> setDemoMode(bool enabled) async {
    if (!tracker.isSupported) return;
    if (demoActive == enabled) return;

    _dataEpoch++;
    settings.demoMode = enabled;
    _scheduleSettingsSave();

    if (enabled) {
      // Persist the real session that was being recorded before replacing the
      // store with generated data.
      _stopLiveTracking();
      await _flushDirty();
      if (_disposed) return;
      demoActive = true;
      _loadDemo();
    } else {
      demoActive = false;
      store.clear();
      _lastTodayFetch = null;
      final Map<String, List<AppSession>> stored = await persistence.loadAll();
      if (_disposed) return;
      _sanitizeDays(stored);
      store.replaceAll(stored);
      if (permissionGranted) {
        if (tracker.canTrackLive) _startLiveTracking();
        if (tracker.canReadHistory) {
          unawaited(syncHistory(days: 90, silent: true));
        }
      }
    }
    if (_disposed) return;
    notifyListeners();
    unawaited(refreshNotificationSchedule(force: true));
  }

  void _scheduleSettingsSave() {
    _saveSettingsTimer?.cancel();
    _saveSettingsTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(settingsPersistence.save(settings.toJson()));
    });
  }

  // ---------------------------------------------------------------------------
  // Permissions & syncing
  // ---------------------------------------------------------------------------

  Future<void> requestPermission() async {
    if (!tracker.canReadHistory) return;
    await tracker.openPermissionSettings();
    // Give the settings screen a moment before re-checking; the lifecycle
    // callback also refreshes the permission when the user comes back.
    Timer(const Duration(milliseconds: 900), () {
      if (_disposed) return;
      unawaited(recheckPermission());
    });
  }

  Future<void> recheckPermission() async {
    if (_disposed || !tracker.isSupported) return;
    final bool allowed = await tracker.hasPermission();
    if (_disposed) return;
    final bool changed = allowed != permissionGranted;
    permissionGranted = allowed;
    if (!allowed) {
      _stopLiveTracking();
    } else {
      if (tracker.canTrackLive) _startLiveTracking();
      if (tracker.canReadHistory) {
        unawaited(syncHistory(days: 90, silent: !changed));
      }
    }
    if (changed) notifyListeners();
  }

  /// Pulls screen-time history from the OS. Only days without local data are
  /// fetched unless [force] is true.
  Future<void> syncHistory({
    int days = 90,
    bool force = false,
    bool silent = false,
  }) async {
    if (!tracker.canReadHistory || !permissionGranted || demoActive) return;
    if (syncing) return;

    syncing = true;
    syncError = null;
    syncDone = 0;
    syncTotal = days;
    final int epoch = _dataEpoch;
    if (!silent) notifyListeners();

    final DateTime anchor = todayDate;
    final int cutoff = historyCutoffMs;
    try {
      for (int i = 0; i < days; i++) {
        if (_disposed || epoch != _dataEpoch) return;
        final DateTime day = addDays(anchor, -i);
        if (cutoff > 0 && addDays(day, 1).millisecondsSinceEpoch <= cutoff) {
          syncDone++;
          continue;
        }
        final bool hasLocal = store.hasDay(day);
        final bool isRecent = i <= 1;
        if (!force && hasLocal && !isRecent) {
          syncDone++;
          continue;
        }
        final List<AppSession> sessions = await tracker.fetchSessions(day);
        if (_disposed || epoch != _dataEpoch) return;
        final List<AppSession> withoutSelf = sessionsAfterCutoff(
          sessions.where((AppSession session) => !_isSelfSession(session)),
          cutoff,
        );
        // Never delete locally stored history just because the OS returned an
        // empty/partial result (older history is often truncated by Android).
        if (withoutSelf.isEmpty && hasLocal) {
          syncDone++;
          continue;
        }
        store.replaceDay(day, withoutSelf);
        _dirtyDays.add(dayKey(day));
        syncDone++;
        if (!silent && syncDone % 4 == 0 && !_disposed) notifyListeners();
        if (syncDone % 10 == 0) {
          await _flushDirty();
        }
        // Yield to the event loop so the UI stays responsive.
        await Future<void>.delayed(Duration.zero);
      }
      if (epoch != _dataEpoch) return;
      await _flushDirty();
      settings.lastSyncMs = DateTime.now().millisecondsSinceEpoch;
      _scheduleSettingsSave();
      _lastTodayFetch = DateTime.now();
      unawaited(refreshNotificationSchedule(force: true));
    } catch (error) {
      syncError = 'Не удалось синхронизировать данные: $error';
      debugPrint('syncHistory: $error');
    } finally {
      syncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Refreshes today (and optionally yesterday) from the OS.
  Future<void> refreshToday({bool notify = true}) async {
    if (_disposed) return;
    now = DateTime.now();
    if (demoActive) {
      _refreshDemoToday();
      if (notify) notifyListeners();
      return;
    }
    if (!tracker.canReadHistory || !permissionGranted) {
      if (notify) notifyListeners();
      return;
    }
    final int epoch = _dataEpoch;
    final DateTime day = todayDate;
    final List<AppSession> sessions = await tracker.fetchSessions(day);
    if (_disposed || epoch != _dataEpoch) return;
    final List<AppSession> cleaned = sessionsAfterCutoff(
      sessions.where((AppSession session) => !_isSelfSession(session)),
      historyCutoffMs,
    );
    final bool hadLocal = store.hasDay(day);
    if (cleaned.isEmpty && hadLocal) {
      // Keep the last known data instead of wiping it on a transient error or
      // an OS query that returned nothing.
      _lastTodayFetch = DateTime.now();
      if (notify) notifyListeners();
      return;
    }
    store.replaceDay(day, cleaned);
    _dirtyDays.add(dayKey(day));
    _lastTodayFetch = DateTime.now();
    if (notify) notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Demo data
  // ---------------------------------------------------------------------------

  bool _isSelfSession(AppSession session) {
    return session.appId.toLowerCase().contains('timeflow');
  }

  /// Removes TimeFlow's own sessions and anything the user explicitly cleared.
  void _sanitizeDays(Map<String, List<AppSession>> days) {
    final int cutoff = historyCutoffMs;
    for (final String key in days.keys.toList()) {
      final List<AppSession> cleaned = sessionsAfterCutoff(
        days[key]!.where((AppSession session) => !_isSelfSession(session)),
        cutoff,
      );
      if (cleaned.isEmpty) {
        days.remove(key);
      } else {
        days[key] = cleaned;
      }
    }
  }

  void _loadDemo() {
    now = DateTime.now();
    final DateTime today = todayDate;
    final Map<String, List<AppSession>> days = DemoData.generate(
      today: today,
      daysBack: 180,
      now: now,
    );
    store.replaceAll(days);
    _demoLoadDate = today;
  }

  void _refreshDemoToday() {
    now = DateTime.now();
    final DateTime today = todayDate;
    if (_demoLoadDate == null || !isSameDay(_demoLoadDate!, today)) {
      _loadDemo();
      return;
    }
    store.replaceDay(today, DemoData.generateDay(today, now: now));
  }

  // ---------------------------------------------------------------------------
  // Desktop live tracking
  // ---------------------------------------------------------------------------

  void _startLiveTracking() {
    if (demoActive || !tracker.canTrackLive || _liveTimer != null) return;
    liveTracking = true;
    _liveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollForeground());
    });
    unawaited(_pollForeground());
  }

  void _stopLiveTracking() {
    _liveTimer?.cancel();
    _liveTimer = null;
    if (liveTracking) liveTracking = false;
    _closeLive(DateTime.now().millisecondsSinceEpoch);
  }

  bool _livePollInFlight = false;

  Future<void> _pollForeground() async {
    if (demoActive || !tracker.canTrackLive || _livePollInFlight) return;
    _livePollInFlight = true;
    try {
      await _pollForegroundInner();
    } finally {
      _livePollInFlight = false;
    }
  }

  Future<void> _pollForegroundInner() async {
    final ForegroundApp? app = await tracker.foregroundApp();
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String appIdLower = app?.id.toLowerCase() ?? '';
    final bool isSelf =
        app != null &&
        (appIdLower.contains('timeflow') ||
            app.name.toLowerCase() == 'timeflow');
    if (app == null || isSelf || app.idleSeconds > 600) {
      final int idleMs = (app?.idleSeconds ?? 0) * 1000;
      _closeLive(nowMs - idleMs);
      return;
    }
    final String? appPath = app.path;
    if (appPath != null &&
        appPath.isNotEmpty &&
        settings.appPaths[app.id] != appPath) {
      settings.appPaths[app.id] = appPath;
      AppIcons.registerPath(app.id, appPath);
      _scheduleSettingsSave();
    }
    if (_liveAppId != app.id) {
      _closeLive(nowMs);
      _liveAppId = app.id;
      _liveAppName = app.name;
      _liveStartMs = nowMs;
    }
    final int start = _liveStartMs ?? nowMs;
    if (nowMs - start < 500) return;
    final DateTime day = dateOnly(DateTime.fromMillisecondsSinceEpoch(nowMs));
    _dirtyDays.addAll(
      store.upsertLiveSession(day, app.id, app.name, start, nowMs),
    );
    _liveTicks++;
    // Repaint at ~6s; the store itself updates every 2s.
    if (_liveTicks % 3 == 0 && !_disposed) notifyListeners();
  }

  void _closeLive(int atMs) {
    final String? appId = _liveAppId;
    final int? start = _liveStartMs;
    if (appId == null || start == null) return;
    final int safeEnd = atMs < start ? start : atMs;
    if (safeEnd - start > 500) {
      final DateTime day = dateOnly(DateTime.fromMillisecondsSinceEpoch(start));
      _dirtyDays.addAll(
        store.upsertLiveSession(
          day,
          appId,
          _liveAppName ?? appId,
          start,
          safeEnd,
        ),
      );
    }
    _liveAppId = null;
    _liveAppName = null;
    _liveStartMs = null;
  }

  /// Forgets the in-progress window without recording it. Used after clearing
  /// history so the pre-clear part of the current session does not come back.
  void _resetLiveSession() {
    _liveAppId = null;
    _liveAppName = null;
    _liveStartMs = null;
  }

  // ---------------------------------------------------------------------------
  // Timers, persistence & lifecycle
  // ---------------------------------------------------------------------------

  void _startTimers() {
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      now = DateTime.now();
      if (demoActive) {
        _refreshDemoToday();
      } else if (tracker.canReadHistory && permissionGranted && !syncing) {
        final DateTime? last = _lastTodayFetch;
        if (last == null || now.difference(last).inSeconds >= 50) {
          await refreshToday(notify: false);
        }
      }
      if (!_disposed) notifyListeners();
      unawaited(refreshNotificationSchedule());
    });

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_flushDirty());
    });
  }

  Future<void> _flushDirty() {
    if (demoActive) {
      _dirtyDays.clear();
      return Future<void>.value();
    }
    final Future<void>? pending = _flushFuture;
    if (pending != null) {
      // Wait for the active write, then make sure keys added meanwhile are
      // persisted too. This matters when switching to demo mode right after
      // closing a live session.
      return pending.then((_) => _flushDirty());
    }
    if (_dirtyDays.isEmpty) return Future<void>.value();
    final Future<void> task = _flushDirtyLoop();
    _flushFuture = task;
    return task.whenComplete(() {
      if (identical(_flushFuture, task)) _flushFuture = null;
    });
  }

  Future<void> _flushDirtyLoop() async {
    while (_dirtyDays.isNotEmpty) {
      if (demoActive) {
        _dirtyDays.clear();
        return;
      }
      final List<String> keys = _dirtyDays.toList();
      _dirtyDays.clear();
      for (final String key in keys) {
        final DateTime? date = parseDayKey(key);
        if (date == null) continue;
        await persistence.saveDay(
          key,
          store.rawDays[key] ?? const <AppSession>[],
        );
      }
    }
  }

  Future<void> flushNow() => _flushDirty();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        now = DateTime.now();
        unawaited(recheckPermission());
        unawaited(refreshToday());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _closeLive(DateTime.now().millisecondsSinceEpoch);
        unawaited(_flushDirty());
        break;
      case AppLifecycleState.detached:
        _closeLive(DateTime.now().millisecondsSinceEpoch);
        unawaited(_flushDirty());
        break;
    }
  }

  Future<void> clearData() async {
    _dataEpoch++;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    _closeLive(nowMs);
    _resetLiveSession();
    store.clear();
    _dirtyDays.clear();
    _lastTodayFetch = null;

    if (!demoActive) {
      await persistence.clear();
      if (_disposed) return;
      settings.lastSyncMs = null;
      // Remember the cutoff so Android's retained system history is not pulled
      // back in immediately after the user clears everything.
      settings.historyCutoffMs = nowMs;
      _scheduleSettingsSave();
    } else {
      // Clearing inside demo mode regenerates the demo; real history on disk
      // must stay untouched until the user leaves demo mode.
      _loadDemo();
    }
    if (!_disposed) notifyListeners();
    unawaited(refreshNotificationSchedule(force: true));
  }

  /// Re-imports Android usage history that was hidden by "clear history".
  Future<void> restoreHistory() async {
    if (!canRestoreHistory) return;
    _dataEpoch++;
    for (int i = 0; i < 100 && syncing && !_disposed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_disposed) return;
    settings.historyCutoffMs = null;
    _lastTodayFetch = null;
    store.clear();
    _dirtyDays.clear();
    _scheduleSettingsSave();
    notifyListeners();
    await syncHistory(days: 90, force: true);
  }

  @override
  void dispose() {
    if (_liveAppId != null) {
      _closeLive(DateTime.now().millisecondsSinceEpoch);
      unawaited(_flushDirty());
    }
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timeTimer?.cancel();
    _liveTimer?.cancel();
    _flushTimer?.cancel();
    _saveSettingsTimer?.cancel();
    DailyNotifications.stopInProcessTimer();
    themeRevision.dispose();
    super.dispose();
  }
}
