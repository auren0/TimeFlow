import 'dart:math' as math;

import 'models.dart';

/// In-memory day index with derived-summary caching.
///
/// Sessions are stored per local day. Every mutation invalidates only the
/// affected day, which keeps repaints during live tracking cheap.
class UsageStore {
  final Map<String, List<AppSession>> _days = <String, List<AppSession>>{};
  final Map<String, DaySummary> _summaryCache = <String, DaySummary>{};

  int get dayCount => _days.length;

  DateTime? get earliestDay {
    DateTime? earliest;
    for (final String key in _days.keys) {
      final DateTime? date = parseDayKey(key);
      if (date == null) continue;
      if (earliest == null || date.isBefore(earliest)) earliest = date;
    }
    return earliest;
  }

  DateTime? get latestDay {
    DateTime? latest;
    for (final String key in _days.keys) {
      final DateTime? date = parseDayKey(key);
      if (date == null) continue;
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    return latest;
  }

  Map<String, List<AppSession>> get rawDays => _days;

  bool hasDay(DateTime day) => _days.containsKey(dayKey(day));

  List<AppSession> sessionsFor(DateTime day) {
    return _days[dayKey(day)] ?? const <AppSession>[];
  }

  DaySummary summaryFor(DateTime day) {
    final String key = dayKey(day);
    final DaySummary? cached = _summaryCache[key];
    if (cached != null) return cached;
    final DaySummary summary = summarizeDay(
      day,
      _days[key] ?? const <AppSession>[],
    );
    _summaryCache[key] = summary;
    return summary;
  }

  List<DaySummary> summariesFor(DateTime start, DateTime endInclusive) {
    return daysInRange(
      start,
      endInclusive,
    ).map(summaryFor).toList(growable: false);
  }

  RangeSummary rangeSummary(DateTime start, DateTime endInclusive) {
    final List<DaySummary> summaries = summariesFor(start, endInclusive);
    return summarizeDaySummaries(start, endInclusive, summaries);
  }

  void replaceAll(Map<String, List<AppSession>> days) {
    _days.clear();
    for (final List<AppSession> sessions in days.values) {
      for (final AppSession session in sessions) {
        for (final AppSession part in splitSessionByDay(session)) {
          _days.putIfAbsent(dayKey(part.start), () => <AppSession>[]).add(part);
        }
      }
    }
    for (final String key in _days.keys.toList()) {
      final List<AppSession> normalized = normalizeSessions(_days[key]!);
      if (normalized.isEmpty) {
        _days.remove(key);
      } else {
        _days[key] = normalized;
      }
    }
    _summaryCache.clear();
  }

  void replaceDay(DateTime day, List<AppSession> sessions) {
    final String key = dayKey(day);
    _days.remove(key);
    _summaryCache.remove(key);

    final Map<String, List<AppSession>> split = <String, List<AppSession>>{};
    for (final AppSession session in sessions) {
      for (final AppSession part in splitSessionByDay(session)) {
        split.putIfAbsent(dayKey(part.start), () => <AppSession>[]).add(part);
      }
    }
    if (split.isEmpty) return;

    for (final MapEntry<String, List<AppSession>> entry in split.entries) {
      final List<AppSession> merged = List<AppSession>.of(
        _days[entry.key] ?? const <AppSession>[],
      )..addAll(entry.value);
      final List<AppSession> normalized = normalizeSessions(merged);
      if (normalized.isEmpty) {
        _days.remove(entry.key);
      } else {
        _days[entry.key] = normalized;
      }
      _summaryCache.remove(entry.key);
    }
  }

  /// Extends the most recent session for [appId] if it's still open, otherwise
  /// starts a new one. Used by desktop live tracking.
  ///
  /// Returns the day keys that changed, including both sides of a session that
  /// crosses midnight.
  Set<String> upsertLiveSession(
    DateTime day,
    String appId,
    String appName,
    int startMs,
    int endMs,
  ) {
    if (endMs - startMs < 500) return const <String>{};
    final Set<String> changed = <String>{};
    final List<AppSession> parts = splitSessionByDay(
      AppSession(
        appId: appId,
        appName: appName,
        startMs: startMs,
        endMs: endMs,
      ),
    );
    for (final AppSession part in parts) {
      final String key = dayKey(part.start);
      final List<AppSession> sessions = List<AppSession>.of(
        _days[key] ?? const <AppSession>[],
      );
      if (sessions.isNotEmpty) {
        final AppSession last = sessions.last;
        if (last.appId == appId && part.startMs <= last.endMs + 5000) {
          sessions[sessions.length - 1] = AppSession(
            appId: appId,
            appName: appName,
            startMs: math.min(last.startMs, part.startMs),
            endMs: math.max(last.endMs, part.endMs),
          );
          _days[key] = sessions;
          _summaryCache.remove(key);
          changed.add(key);
          continue;
        }
      }
      sessions.add(part);
      _days[key] = normalizeSessions(sessions);
      _summaryCache.remove(key);
      changed.add(key);
    }
    return changed;
  }

  void clear() {
    _days.clear();
    _summaryCache.clear();
  }
}
