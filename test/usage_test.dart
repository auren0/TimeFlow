import 'package:flutter_test/flutter_test.dart';
import 'package:timeflow/data/demo_data.dart';
import 'package:timeflow/data/models.dart';
import 'package:timeflow/data/usage_store.dart';
import 'package:timeflow/utils/formatters.dart';

void main() {
  group('DemoData', () {
    test('generates plausible, non-overlapping sessions', () {
      final DateTime day = DateTime(2026, 11, 12);
      final List<AppSession> sessions = DemoData.generateDay(
        day,
        now: DateTime(2026, 11, 12, 23, 59),
      );

      expect(sessions, isNotEmpty);
      for (int i = 1; i < sessions.length; i++) {
        expect(
          sessions[i].startMs,
          greaterThanOrEqualTo(sessions[i - 1].endMs),
          reason: 'sessions must not overlap',
        );
      }

      final DaySummary summary = summarizeDay(day, sessions);
      expect(summary.total.inMinutes, greaterThan(45));
      expect(summary.total.inMinutes, lessThan(24 * 60));
      expect(summary.apps, isNotEmpty);
      expect(summary.hourly.length, 24);
    });

    test('today is clamped to the current time', () {
      final DateTime now = DateTime(2026, 11, 12, 10, 30);
      final List<AppSession> sessions = DemoData.generateDay(now, now: now);
      for (final AppSession session in sessions) {
        expect(session.endMs, lessThanOrEqualTo(now.millisecondsSinceEpoch));
      }
    });
  });

  group('Summaries', () {
    test('clip sessions that cross midnight', () {
      final DateTime day = DateTime(2026, 11, 10);
      final AppSession session = AppSession(
        appId: 'demo.test',
        appName: 'Test',
        startMs: DateTime(2026, 11, 9, 23, 30).millisecondsSinceEpoch,
        endMs: DateTime(2026, 11, 10, 0, 30).millisecondsSinceEpoch,
      );

      final DaySummary summary = summarizeDay(day, <AppSession>[session]);
      expect(summary.total, const Duration(minutes: 30));
      expect(summary.hourly[0], const Duration(minutes: 30));
      expect(summary.apps.single.sessionCount, 1);
    });

    test('aggregate a range and find the busiest day', () {
      final DateTime start = DateTime(2026, 11, 9);
      final DateTime end = DateTime(2026, 11, 10);
      final List<AppSession> dayOne = <AppSession>[
        AppSession(
          appId: 'demo.one',
          appName: 'One',
          startMs: DateTime(2026, 11, 9, 9).millisecondsSinceEpoch,
          endMs: DateTime(2026, 11, 9, 10).millisecondsSinceEpoch,
        ),
      ];
      final List<AppSession> dayTwo = <AppSession>[
        AppSession(
          appId: 'demo.one',
          appName: 'One',
          startMs: DateTime(2026, 11, 10, 9).millisecondsSinceEpoch,
          endMs: DateTime(2026, 11, 10, 12).millisecondsSinceEpoch,
        ),
        AppSession(
          appId: 'demo.two',
          appName: 'Two',
          startMs: DateTime(2026, 11, 10, 13).millisecondsSinceEpoch,
          endMs: DateTime(2026, 11, 10, 14).millisecondsSinceEpoch,
        ),
      ];

      final RangeSummary range = summarizeRange(
        start,
        end,
        <String, List<AppSession>>{dayKey(start): dayOne, dayKey(end): dayTwo},
      );

      expect(range.total, const Duration(hours: 5));
      expect(range.activeDays, 2);
      expect(range.dailyTotals.length, 2);
      expect(range.topDay?.date, end);
      expect(range.apps.first.appId, 'demo.one');
      expect(range.apps.first.duration, const Duration(hours: 4));
    });

    test('normalizes touching sessions of the same app', () {
      final int base = DateTime(2026, 11, 10, 9).millisecondsSinceEpoch;
      final List<AppSession> result = normalizeSessions(<AppSession>[
        AppSession(
          appId: 'a',
          appName: 'A',
          startMs: base,
          endMs: base + 60000,
        ),
        AppSession(
          appId: 'a',
          appName: 'A',
          startMs: base + 61000,
          endMs: base + 120000,
        ),
        AppSession(
          appId: 'b',
          appName: 'B',
          startMs: base + 120000,
          endMs: base + 180000,
        ),
      ]);
      expect(result.length, 2);
      expect(result.first.duration, const Duration(minutes: 2));
    });

    test('active hours ignore an hour where the session only ends', () {
      final DateTime day = DateTime(2026, 11, 10);
      final DaySummary summary = summarizeDay(day, <AppSession>[
        AppSession(
          appId: 'a',
          appName: 'A',
          startMs: DateTime(2026, 11, 10, 9).millisecondsSinceEpoch,
          endMs: DateTime(2026, 11, 10, 11).millisecondsSinceEpoch,
        ),
      ]);
      expect(summary.activeHours, const Duration(hours: 2));
    });

    test('cutoff removes cleared history and clips a straddling session', () {
      final int cutoff = DateTime(2026, 11, 10, 12).millisecondsSinceEpoch;
      final List<AppSession> result = sessionsAfterCutoff(<AppSession>[
        AppSession(
          appId: 'old',
          appName: 'Old',
          startMs: DateTime(2026, 11, 10, 9).millisecondsSinceEpoch,
          endMs: DateTime(2026, 11, 10, 10).millisecondsSinceEpoch,
        ),
        AppSession(
          appId: 'current',
          appName: 'Current',
          startMs: DateTime(2026, 11, 10, 11, 30).millisecondsSinceEpoch,
          endMs: DateTime(2026, 11, 10, 13).millisecondsSinceEpoch,
        ),
      ], cutoff);

      expect(result.length, 1);
      expect(result.single.appId, 'current');
      expect(result.single.startMs, cutoff);
      expect(result.single.duration, const Duration(hours: 1));
    });
  });

  group('UsageStore', () {
    test('splits sessions at midnight when indexing days', () {
      final DateTime dayOne = DateTime(2026, 11, 10);
      final DateTime dayTwo = addDays(dayOne, 1);
      final AppSession spanning = AppSession(
        appId: 'a',
        appName: 'A',
        startMs: DateTime(2026, 11, 10, 23).millisecondsSinceEpoch,
        endMs: DateTime(2026, 11, 11, 0, 30).millisecondsSinceEpoch,
      );
      final UsageStore store = UsageStore()
        ..replaceAll(<String, List<AppSession>>{
          dayKey(dayOne): <AppSession>[spanning],
        });

      expect(store.dayCount, 2);
      expect(store.summaryFor(dayOne).total, const Duration(hours: 1));
      expect(store.summaryFor(dayTwo).total, const Duration(minutes: 30));
    });

    test('live sessions crossing midnight update both days', () {
      final DateTime dayOne = DateTime(2026, 11, 10);
      final DateTime dayTwo = addDays(dayOne, 1);
      final UsageStore store = UsageStore();
      final Set<String> changed = store.upsertLiveSession(
        dayTwo,
        'a',
        'A',
        DateTime(2026, 11, 10, 23).millisecondsSinceEpoch,
        DateTime(2026, 11, 11, 0, 30).millisecondsSinceEpoch,
      );

      expect(changed, <String>{dayKey(dayOne), dayKey(dayTwo)});
      expect(store.summaryFor(dayOne).total, const Duration(hours: 1));
      expect(store.summaryFor(dayTwo).total, const Duration(minutes: 30));
    });

    test('range summary matches direct aggregation', () {
      final DateTime start = DateTime(2026, 11, 8);
      final DateTime end = DateTime(2026, 11, 10);
      final Map<String, List<AppSession>> days = <String, List<AppSession>>{
        dayKey(start): <AppSession>[
          AppSession(
            appId: 'a',
            appName: 'A',
            startMs: DateTime(2026, 11, 8, 9).millisecondsSinceEpoch,
            endMs: DateTime(2026, 11, 8, 10).millisecondsSinceEpoch,
          ),
        ],
        dayKey(end): <AppSession>[
          AppSession(
            appId: 'a',
            appName: 'A',
            startMs: DateTime(2026, 11, 10, 9).millisecondsSinceEpoch,
            endMs: DateTime(2026, 11, 10, 12).millisecondsSinceEpoch,
          ),
        ],
      };
      final UsageStore store = UsageStore()..replaceAll(days);

      final RangeSummary cached = store.rangeSummary(start, end);
      final RangeSummary direct = summarizeRange(start, end, days);

      expect(cached.total, direct.total);
      expect(cached.activeDays, direct.activeDays);
      expect(cached.dailyTotals, direct.dailyTotals);
      expect(cached.topDay?.date, direct.topDay?.date);
      expect(cached.apps.single.duration, direct.apps.single.duration);
    });
  });

  group('Dates', () {
    test('adds calendar days across month and year boundaries', () {
      expect(addDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2024, 2, 28), 1), DateTime(2024, 2, 29));
      expect(addDays(DateTime(2026, 3, 2), -2), DateTime(2026, 2, 28));
    });

    test('builds inclusive ranges', () {
      final List<DateTime> days = daysInRange(
        DateTime(2026, 12, 30),
        DateTime(2027, 1, 2),
      );
      expect(days.map(dateNumeric), <String>[
        '30.12.2026',
        '31.12.2026',
        '01.01.2027',
        '02.01.2027',
      ]);
    });
  });

  group('Formatters', () {
    test('build correct Russian plurals', () {
      expect(pluralDays(1), '1 день');
      expect(pluralDays(2), '2 дня');
      expect(pluralDays(11), '11 дней');
      expect(pluralDays(21), '21 день');
      expect(pluralSessions(1), '1 сессия');
      expect(pluralSessions(3), '3 сессии');
      expect(pluralSessions(12), '12 сессий');
      expect(pluralApps(1), '1 приложение');
      expect(pluralApps(4), '4 приложения');
      expect(pluralAppsWord(5), 'приложений');
    });
  });
}
