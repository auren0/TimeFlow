import 'package:flutter_test/flutter_test.dart';
import 'package:timeflow/data/backup.dart';
import 'package:timeflow/data/local_storage.dart';
import 'package:timeflow/data/models.dart';
import 'package:timeflow/data/usage_tracker.dart';
import 'package:timeflow/state/app_settings.dart';
import 'package:timeflow/state/timeflow_state.dart';

class _FakeTracker implements UsageTracker {
  bool permission = false;
  final Map<String, List<AppSession>> days = <String, List<AppSession>>{};

  @override
  final TrackerKind kind = TrackerKind.android;

  @override
  bool get canReadHistory => true;

  @override
  bool get canTrackLive => false;

  @override
  bool get isSupported => true;

  @override
  String get platformName => 'Android';

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> openPermissionSettings() async {}

  @override
  Future<List<AppSession>> fetchSessions(DateTime day) async {
    return List<AppSession>.of(days[dayKey(day)] ?? const <AppSession>[]);
  }

  @override
  Future<ForegroundApp?> foregroundApp() async => null;
}

class _MemoryUsagePersistence implements UsagePersistence {
  Map<String, List<AppSession>> stored = <String, List<AppSession>>{};

  @override
  Future<Map<String, List<AppSession>>> loadAll() async {
    return <String, List<AppSession>>{
      for (final MapEntry<String, List<AppSession>> entry in stored.entries)
        entry.key: List<AppSession>.of(entry.value),
    };
  }

  @override
  Future<void> saveDay(String key, List<AppSession> sessions) async {
    if (sessions.isEmpty) {
      stored.remove(key);
    } else {
      stored[key] = List<AppSession>.of(sessions);
    }
  }

  @override
  Future<void> clear() async {
    stored.clear();
  }
}

class _MemorySettingsPersistence implements SettingsPersistence {
  Map<String, dynamic> stored = <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> load() async => Map<String, dynamic>.of(stored);

  @override
  Future<void> save(Map<String, dynamic> values) async {
    stored = Map<String, dynamic>.of(values);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTracker tracker;
  late _MemoryUsagePersistence usage;
  late _MemorySettingsPersistence settings;
  late TimeFlowState state;

  setUp(() async {
    tracker = _FakeTracker();
    usage = _MemoryUsagePersistence();
    settings = _MemorySettingsPersistence();
    state = TimeFlowState(
      tracker: tracker,
      persistence: usage,
      settingsPersistence: settings,
    );
  });

  tearDown(() {
    state.dispose();
  });

  AppSession sessionOn(DateTime day, String appId) {
    return AppSession(
      appId: appId,
      appName: appId,
      startMs: DateTime(day.year, day.month, day.day, 9).millisecondsSinceEpoch,
      endMs: DateTime(day.year, day.month, day.day, 10).millisecondsSinceEpoch,
    );
  }

  test('clear history hides old system data and can be restored', () async {
    final DateTime yesterday = addDays(dateOnly(DateTime.now()), -1);
    final String key = dayKey(yesterday);

    usage.stored[key] = <AppSession>[sessionOn(yesterday, 'com.example.app')];
    await state.init();
    expect(state.store.dayCount, 1);

    await state.clearData();
    expect(state.store.dayCount, 0);
    expect(state.historyCutoffMs, greaterThan(0));

    // Android still has the old history, but the cutoff must keep it hidden.
    state.permissionGranted = true;
    expect(state.canRestoreHistory, isTrue);
    tracker.days[key] = <AppSession>[sessionOn(yesterday, 'com.example.app')];
    await state.syncHistory(days: 3, force: true);
    expect(state.store.dayCount, 0);

    await state.restoreHistory();
    expect(state.historyCutoffMs, 0);
    expect(state.store.dayCount, 1);
  });

  test('clearing in demo mode keeps real history on disk', () async {
    final DateTime yesterday = addDays(dateOnly(DateTime.now()), -1);
    final String key = dayKey(yesterday);
    usage.stored[key] = <AppSession>[sessionOn(yesterday, 'com.example.app')];
    settings.stored = <String, dynamic>{'demo': true};

    await state.init();
    expect(state.demoActive, isTrue);

    await state.clearData();
    expect(state.demoActive, isTrue);
    expect(usage.stored, isNotEmpty);
    expect(usage.stored[key], isNotEmpty);
  });

  test('empty OS result keeps already-saved data for today', () async {
    tracker.permission = true;
    final DateTime today = dateOnly(DateTime.now());
    state.permissionGranted = true;
    state.store.replaceDay(today, <AppSession>[
      sessionOn(today, 'com.example.app'),
    ]);

    await state.refreshToday();
    expect(state.store.summaryFor(today).apps, isNotEmpty);
  });

  test('TimeFlow itself is filtered from today data', () async {
    tracker.permission = true;
    state.permissionGranted = true;
    final DateTime today = dateOnly(DateTime.now());
    tracker.days[dayKey(today)] = <AppSession>[
      sessionOn(today, 'com.example.timeflow'),
      sessionOn(today, 'com.example.app'),
    ];

    await state.refreshToday();
    final List<AppUsage> apps = state.store.summaryFor(today).apps;
    expect(apps.length, 1);
    expect(apps.single.appId, 'com.example.app');
  });

  test('backup import replaces history and applies appearance', () async {
    final DateTime today = dateOnly(DateTime.now());
    final DateTime oldDay = addDays(today, -3);
    final DateTime importedDay = addDays(today, -1);
    usage.stored[dayKey(oldDay)] = <AppSession>[sessionOn(oldDay, 'old.app')];
    await state.init();
    expect(state.store.dayCount, 1);

    final String payload = TimeFlowBackup.encode(
      days: <String, List<AppSession>>{
        dayKey(importedDay): <AppSession>[
          sessionOn(importedDay, 'imported.app'),
        ],
      },
      themeIndex: AppThemeMode.dark.index,
      paletteIndex: 3,
    );
    final BackupImportResult result = await state.importBackup(
      payload,
      replace: true,
    );

    expect(result.replaced, isTrue);
    expect(result.dayCount, 1);
    expect(state.store.hasDay(oldDay), isFalse);
    expect(state.store.hasDay(importedDay), isTrue);
    expect(usage.stored.containsKey(dayKey(oldDay)), isFalse);
    expect(state.settings.themeMode, AppThemeMode.dark);
    expect(state.settings.paletteIndex, 3);
  });
}
