import 'dart:math' as math;

/// A single continuous period of time spent in one application.
class AppSession {
  const AppSession({
    required this.appId,
    required this.appName,
    required this.startMs,
    required this.endMs,
  });

  final String appId;
  final String appName;
  final int startMs;
  final int endMs;

  Duration get duration => Duration(milliseconds: endMs - startMs);

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startMs);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endMs);

  AppSession copyWith({int? startMs, int? endMs, String? appName}) {
    return AppSession(
      appId: appId,
      appName: appName ?? this.appName,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'a': appId,
    'n': appName,
    's': startMs,
    'e': endMs,
  };

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      appId: json['a'] as String? ?? 'unknown',
      appName: json['n'] as String? ?? 'Приложение',
      startMs: (json['s'] as num?)?.toInt() ?? 0,
      endMs: (json['e'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() => 'AppSession($appName, $startMs..$endMs)';
}

/// Aggregated time for one application.
class AppUsage {
  const AppUsage({
    required this.appId,
    required this.appName,
    required this.duration,
    required this.sessionCount,
    this.lastUsed,
  });

  final String appId;
  final String appName;
  final Duration duration;
  final int sessionCount;
  final DateTime? lastUsed;

  double shareOf(Duration total) {
    if (total.inMilliseconds <= 0) return 0;
    return duration.inMilliseconds / total.inMilliseconds;
  }
}

/// Everything that can be derived from a single day of sessions.
class DaySummary {
  DaySummary({
    required this.date,
    required this.total,
    required this.apps,
    required this.hourly,
    required this.sessions,
  });

  final DateTime date;
  final Duration total;
  final List<AppUsage> apps;

  /// Time spent in each hour of the day (0..23).
  final List<Duration> hourly;

  /// Sessions clipped to this day, sorted by start time.
  final List<AppSession> sessions;

  bool get isEmpty => total.inSeconds == 0;

  AppUsage? get topApp => apps.isEmpty ? null : apps.first;

  int get sessionCount => sessions.length;

  Duration get activeHours {
    int hours = 0;
    for (final Duration entry in hourly) {
      if (entry > Duration.zero) hours++;
    }
    return Duration(hours: hours);
  }

  Duration get longestSession {
    Duration best = Duration.zero;
    for (final AppSession s in sessions) {
      if (s.duration > best) best = s.duration;
    }
    return best;
  }

  /// Average length of a session in the day.
  Duration get averageSession {
    if (sessions.isEmpty) return Duration.zero;
    return Duration(milliseconds: total.inMilliseconds ~/ sessions.length);
  }
}

/// Summary over an arbitrary range of days.
class RangeSummary {
  RangeSummary({
    required this.start,
    required this.end,
    required this.total,
    required this.apps,
    required this.dailyTotals,
    required this.activeDays,
    required this.topDay,
  });

  final DateTime start;
  final DateTime end;
  final Duration total;
  final List<AppUsage> apps;

  /// One entry per day in the range, oldest first.
  final List<Duration> dailyTotals;

  /// Number of days with any recorded activity.
  final int activeDays;

  /// Day with the most screen time in the range.
  final DaySummary? topDay;

  Duration get averagePerActiveDay {
    if (activeDays <= 0) return Duration.zero;
    return Duration(milliseconds: total.inMilliseconds ~/ activeDays);
  }
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String dayKey(DateTime day) {
  final String m = day.month.toString().padLeft(2, '0');
  final String d = day.day.toString().padLeft(2, '0');
  return '${day.year}-$m-$d';
}

DateTime? parseDayKey(String key) {
  final List<String> parts = key.split('-');
  if (parts.length != 3) return null;
  final int? y = int.tryParse(parts[0]);
  final int? m = int.tryParse(parts[1]);
  final int? d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Returns a local midnight [days] away from [day]. Unlike
/// `day.add(Duration(days: n))`, this stays on the intended calendar date
/// across daylight-saving transitions.
DateTime addDays(DateTime day, int days) {
  final DateTime value = dateOnly(day);
  return DateTime(value.year, value.month, value.day + days);
}

int dayDifference(DateTime a, DateTime b) {
  final DateTime ua = DateTime.utc(a.year, a.month, a.day);
  final DateTime ub = DateTime.utc(b.year, b.month, b.day);
  return ua.difference(ub).inDays;
}

List<DateTime> daysInRange(DateTime start, DateTime endInclusive) {
  final DateTime s = dateOnly(start);
  final DateTime e = dateOnly(endInclusive);
  final int count = dayDifference(e, s);
  if (count < 0) return const <DateTime>[];
  return List<DateTime>.generate(
    count + 1,
    (int i) => DateTime(s.year, s.month, s.day + i),
  );
}

DaySummary summarizeDay(DateTime day, Iterable<AppSession> raw) {
  final DateTime start = dateOnly(day);
  final DateTime endExclusive = DateTime(
    start.year,
    start.month,
    start.day + 1,
  );
  final int rangeStart = start.millisecondsSinceEpoch;
  final int rangeEnd = endExclusive.millisecondsSinceEpoch;

  final List<AppSession> clipped = <AppSession>[];
  for (final AppSession session in raw) {
    final int from = math.max(session.startMs, rangeStart);
    final int to = math.min(session.endMs, rangeEnd);
    if (to - from < 1000) continue;
    clipped.add(session.copyWith(startMs: from, endMs: to));
  }
  clipped.sort((AppSession a, AppSession b) => a.startMs.compareTo(b.startMs));

  final List<Duration> hourly = List<Duration>.filled(24, Duration.zero);
  final Map<String, _Agg> aggregates = <String, _Agg>{};
  Duration total = Duration.zero;

  for (final AppSession session in clipped) {
    final Duration sessionDuration = session.duration;
    total += sessionDuration;

    final _Agg agg = aggregates.putIfAbsent(
      session.appId,
      () => _Agg(session.appId, session.appName),
    );
    agg.duration += sessionDuration;
    agg.sessionCount += 1;
    final DateTime? last = agg.lastUsed;
    if (last == null || session.end.isAfter(last)) {
      agg.lastUsed = session.end;
    }

    int cursor = session.startMs;
    while (cursor < session.endMs) {
      final DateTime local = DateTime.fromMillisecondsSinceEpoch(cursor);
      final int hourEnd = DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
      ).add(const Duration(hours: 1)).millisecondsSinceEpoch;
      final int segmentEnd = math.min(session.endMs, hourEnd);
      if (segmentEnd <= cursor) break;
      hourly[local.hour] =
          hourly[local.hour] + Duration(milliseconds: segmentEnd - cursor);
      cursor = segmentEnd;
    }
  }

  final List<AppUsage> apps =
      aggregates.values
          .map(
            (_Agg a) => AppUsage(
              appId: a.appId,
              appName: a.appName,
              duration: a.duration,
              sessionCount: a.sessionCount,
              lastUsed: a.lastUsed,
            ),
          )
          .toList()
        ..sort((AppUsage a, AppUsage b) => b.duration.compareTo(a.duration));

  return DaySummary(
    date: start,
    total: total,
    apps: apps,
    hourly: hourly,
    sessions: clipped,
  );
}

RangeSummary summarizeRange(
  DateTime start,
  DateTime endInclusive,
  Map<String, List<AppSession>> days,
) {
  final List<DaySummary> summaries = daysInRange(start, endInclusive)
      .map(
        (DateTime date) =>
            summarizeDay(date, days[dayKey(date)] ?? const <AppSession>[]),
      )
      .toList(growable: false);
  return summarizeDaySummaries(start, endInclusive, summaries);
}

/// Aggregates already-computed day summaries. [summaries] must contain exactly
/// one entry per day between [start] and [endInclusive], oldest first.
///
/// Keeping this separate lets [UsageStore] reuse its per-day cache instead of
/// re-counting every session for week/month views.
RangeSummary summarizeDaySummaries(
  DateTime start,
  DateTime endInclusive,
  Iterable<DaySummary> summaries,
) {
  final Map<String, _Agg> aggregates = <String, _Agg>{};
  final List<Duration> dailyTotals = <Duration>[];
  Duration total = Duration.zero;
  int activeDays = 0;
  DaySummary? topDay;

  for (final DaySummary summary in summaries) {
    dailyTotals.add(summary.total);
    total += summary.total;
    if (!summary.isEmpty) {
      activeDays += 1;
      if (topDay == null || summary.total > topDay.total) {
        topDay = summary;
      }
    }
    for (final AppUsage app in summary.apps) {
      final _Agg agg = aggregates.putIfAbsent(
        app.appId,
        () => _Agg(app.appId, app.appName),
      );
      agg.duration += app.duration;
      agg.sessionCount += app.sessionCount;
      final DateTime? last = agg.lastUsed;
      if (app.lastUsed != null &&
          (last == null || app.lastUsed!.isAfter(last))) {
        agg.lastUsed = app.lastUsed;
      }
    }
  }

  final List<AppUsage> apps =
      aggregates.values
          .map(
            (_Agg a) => AppUsage(
              appId: a.appId,
              appName: a.appName,
              duration: a.duration,
              sessionCount: a.sessionCount,
              lastUsed: a.lastUsed,
            ),
          )
          .toList()
        ..sort((AppUsage a, AppUsage b) => b.duration.compareTo(a.duration));

  return RangeSummary(
    start: dateOnly(start),
    end: dateOnly(endInclusive),
    total: total,
    apps: apps,
    dailyTotals: dailyTotals,
    activeDays: activeDays,
    topDay: topDay,
  );
}

/// Splits a session at local midnights so every returned part belongs to one
/// calendar day. Short (<1 s) fragments are discarded.
List<AppSession> splitSessionByDay(AppSession session) {
  final List<AppSession> parts = <AppSession>[];
  int cursor = session.startMs;
  while (cursor < session.endMs) {
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(cursor);
    final int nextMidnight = DateTime(
      local.year,
      local.month,
      local.day + 1,
    ).millisecondsSinceEpoch;
    final int partEnd = math.min(session.endMs, nextMidnight);
    if (partEnd <= cursor) break;
    if (partEnd - cursor >= 1000) {
      parts.add(session.copyWith(startMs: cursor, endMs: partEnd));
    }
    cursor = partEnd;
  }
  return parts;
}

/// Drops sessions that ended before [cutoffMs] and clips the start of sessions
/// that straddle the cutoff. Used after "clear history" so old OS history is
/// not silently imported again.
List<AppSession> sessionsAfterCutoff(Iterable<AppSession> input, int cutoffMs) {
  if (cutoffMs <= 0) return List<AppSession>.of(input);
  final List<AppSession> result = <AppSession>[];
  for (final AppSession session in input) {
    if (session.endMs <= cutoffMs) continue;
    final int start = math.max(session.startMs, cutoffMs);
    if (session.endMs - start >= 1000) {
      result.add(session.copyWith(startMs: start));
    }
  }
  return result;
}

/// Combines adjacent/overlapping sessions of the same app.
List<AppSession> normalizeSessions(Iterable<AppSession> input) {
  final List<AppSession> sorted =
      input.where((AppSession s) => s.endMs - s.startMs >= 1000).toList()
        ..sort((AppSession a, AppSession b) => a.startMs.compareTo(b.startMs));

  final List<AppSession> result = <AppSession>[];
  for (final AppSession session in sorted) {
    if (result.isNotEmpty) {
      final AppSession last = result.last;
      final bool sameApp = last.appId == session.appId;
      final bool touching = session.startMs <= last.endMs + 1000;
      if (sameApp && touching) {
        result[result.length - 1] = last.copyWith(
          endMs: math.max(last.endMs, session.endMs),
        );
        continue;
      }
      // Overlapping sessions from different apps: trim to keep the day sane.
      if (session.startMs < last.endMs) {
        final int newStart = last.endMs;
        if (session.endMs - newStart >= 1000) {
          result.add(session.copyWith(startMs: newStart));
        }
        continue;
      }
    }
    result.add(session);
  }
  return result;
}

class _Agg {
  _Agg(this.appId, this.appName);

  final String appId;
  final String appName;
  Duration duration = Duration.zero;
  int sessionCount = 0;
  DateTime? lastUsed;
}
