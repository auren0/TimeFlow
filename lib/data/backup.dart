import 'dart:convert';

import 'models.dart';

/// Result of a successful local backup import.
class BackupImportResult {
  const BackupImportResult({
    required this.dayCount,
    required this.sessionCount,
    required this.replaced,
  });

  final int dayCount;
  final int sessionCount;
  final bool replaced;
}

/// Parsed contents of a TimeFlow backup file.
class BackupPayload {
  const BackupPayload({
    required this.days,
    required this.sessionCount,
    this.themeIndex,
    this.paletteIndex,
  });

  final Map<String, List<AppSession>> days;
  final int sessionCount;
  final int? themeIndex;
  final int? paletteIndex;
}

/// JSON format for exporting and importing all local progress.
abstract final class TimeFlowBackup {
  static const String format = 'timeflow-backup';
  static const int version = 1;

  static String encode({
    required Map<String, List<AppSession>> days,
    required int themeIndex,
    required int paletteIndex,
  }) {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'format': format,
      'version': version,
      'app': 'TimeFlow',
      'exportedAt': DateTime.now().toIso8601String(),
      'theme': themeIndex,
      'palette': paletteIndex,
      'days': <String, dynamic>{
        for (final MapEntry<String, List<AppSession>> entry in days.entries)
          entry.key: entry.value.map((AppSession s) => s.toJson()).toList(),
      },
    });
  }

  static BackupPayload parse(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      throw const FormatException('Файл не является корректным JSON.');
    }
    if (decoded is! Map || decoded['format'] != format) {
      throw const FormatException('Это не резервная копия TimeFlow.');
    }
    final Object? daysRaw = decoded['days'];
    if (daysRaw is! Map) {
      throw const FormatException('В резервной копии нет истории.');
    }

    final Map<String, List<AppSession>> days = <String, List<AppSession>>{};
    for (final MapEntry<Object?, Object?> entry in daysRaw.entries) {
      final Object? key = entry.key;
      if (key is! String || parseDayKey(key) == null) continue;
      final Object? value = entry.value;
      if (value is! List) continue;

      final List<AppSession> sessions = <AppSession>[];
      for (final Object? item in value) {
        if (item is! Map) continue;
        final AppSession session = AppSession.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (session.endMs > session.startMs) sessions.add(session);
      }
      if (sessions.isEmpty) continue;
      days[key] = normalizeSessions(sessions);
    }

    int sessionCount = 0;
    for (final List<AppSession> sessions in days.values) {
      sessionCount += sessions.length;
    }

    return BackupPayload(
      days: days,
      sessionCount: sessionCount,
      themeIndex: (decoded['theme'] as num?)?.toInt(),
      paletteIndex: (decoded['palette'] as num?)?.toInt(),
    );
  }
}
