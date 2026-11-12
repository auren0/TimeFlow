import 'dart:math' as math;

import 'models.dart';

/// Deterministic demo data so the app is fully explorable on platforms where
/// the OS does not expose screen-time data (Linux) and in the explicit
/// "demo mode".
abstract final class DemoData {
  static const List<_DemoApp> _apps = <_DemoApp>[
    _DemoApp('instagram', 'Instagram', 1.15, 1.55, 6, 24, _Bias.social),
    _DemoApp('youtube', 'YouTube', 1.35, 1.75, 6, 55, _Bias.video),
    _DemoApp('telegram', 'Telegram', 1.6, 1.5, 3, 18, _Bias.social),
    _DemoApp('chrome', 'Chrome', 1.1, 0.95, 5, 40, _Bias.any),
    _DemoApp('spotify', 'Spotify', 0.8, 0.9, 8, 45, _Bias.music),
    _DemoApp('notion', 'Notion', 0.7, 0.2, 6, 35, _Bias.work),
    _DemoApp('code', 'Visual Studio Code', 1.6, 0.45, 8, 55, _Bias.work),
    _DemoApp('figma', 'Figma', 0.65, 0.2, 8, 40, _Bias.work),
    _DemoApp('gmail', 'Gmail', 0.55, 0.2, 3, 14, _Bias.work),
    _DemoApp('whatsapp', 'WhatsApp', 1.1, 1.15, 2, 16, _Bias.social),
    _DemoApp('tiktok', 'TikTok', 0.55, 1.5, 4, 30, _Bias.video),
    _DemoApp('discord', 'Discord', 0.35, 1.1, 4, 40, _Bias.evening),
    _DemoApp('steam', 'Steam', 0.25, 1.2, 15, 85, _Bias.evening),
    _DemoApp('netflix', 'Netflix', 0.5, 1.25, 20, 75, _Bias.video),
    _DemoApp('word', 'Word', 0.45, 0.1, 8, 35, _Bias.work),
    _DemoApp('excel', 'Excel', 0.4, 0.1, 8, 40, _Bias.work),
    _DemoApp('slack', 'Slack', 0.6, 0.08, 3, 16, _Bias.work),
    _DemoApp('maps', 'Google Maps', 0.2, 0.3, 3, 20, _Bias.any),
    _DemoApp('duolingo', 'Duolingo', 0.22, 0.3, 4, 12, _Bias.morning),
    _DemoApp('timeflow', 'TimeFlow', 0.24, 0.22, 3, 18, _Bias.any),
    _DemoApp('camera', 'Камера', 0.2, 0.35, 2, 10, _Bias.any),
    _DemoApp('reddit', 'Reddit', 0.35, 0.5, 4, 20, _Bias.evening),
    _DemoApp('zoom', 'Zoom', 0.4, 0.02, 15, 55, _Bias.work),
    _DemoApp('photos', 'Фото', 0.18, 0.35, 3, 15, _Bias.any),
    _DemoApp('messages', 'Сообщения', 0.5, 0.55, 2, 10, _Bias.social),
    _DemoApp('calendar', 'Календарь', 0.16, 0.05, 2, 10, _Bias.work),
  ];

  /// Builds demo days for [daysBack] days ending today (inclusive).
  static Map<String, List<AppSession>> generate({
    required DateTime today,
    int daysBack = 420,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();
    final Map<String, List<AppSession>> result = <String, List<AppSession>>{};
    final DateTime start = addDays(today, -daysBack);
    for (int i = 0; i <= daysBack; i++) {
      final DateTime day = addDays(start, i);
      result[dayKey(day)] = generateDay(day, now: current);
    }
    return result;
  }

  static List<AppSession> generateDay(DateTime day, {DateTime? now}) {
    final DateTime current = now ?? DateTime.now();
    final DateTime date = dateOnly(day);
    final bool today = isSameDay(date, current);
    if (date.isAfter(dateOnly(current))) return const <AppSession>[];

    final int seed = date.year * 10000 + date.month * 100 + date.day;
    final math.Random random = math.Random(seed);

    // A few days off / travel days with little or no usage. Today is always
    // generated so the app never opens on an empty demo dashboard.
    final double roll = random.nextDouble();
    if (!today && roll < 0.025) return const <AppSession>[];
    final bool weekend = date.weekday >= DateTime.saturday;
    final bool lightDay = !today && roll < 0.14;

    double targetMinutes = weekend ? 385 : 315;
    targetMinutes += (random.nextDouble() - 0.45) * 170;
    if (lightDay) targetMinutes *= 0.35;

    // Start of day, in minutes from midnight.
    int clock = (7 * 60 + random.nextInt(95)).clamp(0, 23 * 60);
    int limit = (23 * 60 + 45).clamp(0, 24 * 60);

    if (today) {
      final int nowMinutes = current.hour * 60 + current.minute;
      if (nowMinutes < 7 * 60) return const <AppSession>[];
      limit = nowMinutes;
      final double fraction = ((nowMinutes - 7 * 60) / (16 * 60)).clamp(
        0.14,
        1.0,
      );
      targetMinutes *= fraction;
      if (clock > nowMinutes - 30) {
        clock = math.max(0, nowMinutes - 45);
      }
    }

    final List<AppSession> sessions = <AppSession>[];
    int spent = 0;
    int guard = 0;

    while (clock < limit && spent < targetMinutes && guard++ < 400) {
      final double hour = clock / 60.0;
      final _DemoApp app = _pickApp(random, hour, weekend);
      final int maxLen = today
          ? math.min(app.maxSession, math.max(3, limit - clock))
          : app.maxSession;
      final int minLen = math.min(app.minSession, maxLen);
      if (maxLen < 3) break;

      int length = minLen + random.nextInt(math.max(1, maxLen - minLen + 1));
      if (clock + length > limit) {
        length = limit - clock;
      }
      if (length < 2) break;

      final int startMs =
          date.millisecondsSinceEpoch + clock * Duration.millisecondsPerMinute;
      final int endMs = startMs + length * Duration.millisecondsPerMinute;
      sessions.add(
        AppSession(
          appId: 'demo.${app.id}',
          appName: app.name,
          startMs: startMs,
          endMs: endMs,
        ),
      );
      spent += length;

      // Short break between sessions, sometimes a longer pause.
      int gap = 1 + random.nextInt(9);
      if (random.nextDouble() < 0.16) gap += 12 + random.nextInt(28);
      clock += length + gap;
    }

    return sessions;
  }

  static _DemoApp _pickApp(math.Random random, double hour, bool weekend) {
    final List<double> weights = <double>[];
    double total = 0;
    for (final _DemoApp app in _apps) {
      double weight = weekend ? app.weekendWeight : app.weekdayWeight;
      weight *= app.bias.factor(hour);
      weights.add(weight);
      total += weight;
    }
    double pick = random.nextDouble() * total;
    for (int i = 0; i < _apps.length; i++) {
      pick -= weights[i];
      if (pick <= 0) return _apps[i];
    }
    return _apps.last;
  }
}

enum _Bias {
  work,
  social,
  video,
  evening,
  morning,
  music,
  any;

  double factor(double hour) {
    switch (this) {
      case _Bias.work:
        if (hour < 8 || hour > 20) return 0.04;
        if (hour < 9) return 0.35;
        if (hour < 18) return 1.0;
        if (hour < 20) return 0.45;
        return 0.05;
      case _Bias.social:
        if (hour < 6) return 0.0;
        if (hour < 9) return 0.85;
        if (hour < 12) return 0.55;
        if (hour < 14) return 0.9;
        if (hour < 17) return 0.5;
        if (hour < 23) return 1.0;
        return 0.5;
      case _Bias.video:
        if (hour < 7) return 0.05;
        if (hour < 12) return 0.25;
        if (hour < 14) return 0.7;
        if (hour < 18) return 0.4;
        if (hour < 24) return 1.0;
        return 0.4;
      case _Bias.evening:
        if (hour < 15) return 0.05;
        if (hour < 18) return 0.35;
        if (hour < 24) return 1.0;
        return 0.3;
      case _Bias.morning:
        if (hour < 6) return 0.0;
        if (hour < 10) return 1.0;
        if (hour < 17) return 0.25;
        if (hour < 22) return 0.6;
        return 0.1;
      case _Bias.music:
        if (hour < 6) return 0.0;
        if (hour < 10) return 1.0;
        if (hour < 16) return 0.4;
        if (hour < 22) return 0.8;
        return 0.05;
      case _Bias.any:
        return 1.0;
    }
  }
}

class _DemoApp {
  const _DemoApp(
    this.id,
    this.name,
    this.weekdayWeight,
    this.weekendWeight,
    this.minSession,
    this.maxSession,
    this.bias,
  );

  final String id;
  final String name;
  final double weekdayWeight;
  final double weekendWeight;
  final int minSession;
  final int maxSession;
  final _Bias bias;
}
