import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Reads and writes per-day JSON files in the application support directory.
///
/// One file per day keeps writes tiny and makes the calendar feel instant even
/// with a year of history.
class UsagePersistence {
  UsagePersistence();

  Directory? _dir;
  bool _unavailable = false;

  Future<Directory?> _ensureDir() async {
    if (_unavailable) return null;
    if (_dir != null) return _dir;
    try {
      final Directory support = await getApplicationSupportDirectory();
      final Directory dir = Directory('${support.path}/usage');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _dir = dir;
      return dir;
    } catch (error) {
      debugPrint('UsagePersistence: storage unavailable ($error)');
      _unavailable = true;
      return null;
    }
  }

  Future<Map<String, List<AppSession>>> loadAll() async {
    final Directory? dir = await _ensureDir();
    if (dir == null) return <String, List<AppSession>>{};
    final Map<String, List<AppSession>> result = <String, List<AppSession>>{};
    try {
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final String name = entity.uri.pathSegments.last;
        final String key = name.substring(0, name.length - 5);
        if (parseDayKey(key) == null) continue;
        try {
          final Object? decoded = jsonDecode(await entity.readAsString());
          if (decoded is! List) continue;
          final List<AppSession> sessions = decoded
              .whereType<Map<String, dynamic>>()
              .map(AppSession.fromJson)
              .where((AppSession s) => s.endMs > s.startMs)
              .toList();
          if (sessions.isNotEmpty) {
            result[key] = normalizeSessions(sessions);
          }
        } catch (_) {
          // Ignore a single corrupt file, keep the rest of the history.
        }
      }
    } catch (error) {
      debugPrint('UsagePersistence.loadAll: $error');
    }
    return result;
  }

  Future<void> saveDay(String key, List<AppSession> sessions) async {
    final Directory? dir = await _ensureDir();
    if (dir == null) return;
    try {
      final File file = File('${dir.path}/$key.json');
      if (sessions.isEmpty) {
        if (await file.exists()) await file.delete();
        return;
      }
      final String payload = jsonEncode(
        sessions.map((AppSession s) => s.toJson()).toList(),
      );
      final File tmp = File('${file.path}.tmp');
      await tmp.writeAsString(payload, flush: true);
      await tmp.rename(file.path);
    } catch (error) {
      debugPrint('UsagePersistence.saveDay($key): $error');
    }
  }

  Future<void> clear() async {
    final Directory? dir = await _ensureDir();
    if (dir == null) return;
    try {
      await dir.delete(recursive: true);
      _dir = null;
    } catch (error) {
      debugPrint('UsagePersistence.clear: $error');
    }
  }
}

/// Small JSON-file backed settings storage. Kept separate from usage data so
/// clearing statistics never resets preferences.
class SettingsPersistence {
  SettingsPersistence();

  File? _file;
  bool _unavailable = false;

  Future<File?> _ensureFile() async {
    if (_unavailable) return null;
    if (_file != null) return _file;
    try {
      final Directory support = await getApplicationSupportDirectory();
      if (!await support.exists()) await support.create(recursive: true);
      _file = File('${support.path}/settings.json');
      return _file;
    } catch (error) {
      debugPrint('SettingsPersistence: storage unavailable ($error)');
      _unavailable = true;
      return null;
    }
  }

  Future<Map<String, dynamic>> load() async {
    final File? file = await _ensureFile();
    if (file == null) return <String, dynamic>{};
    try {
      if (!await file.exists()) return <String, dynamic>{};
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (error) {
      debugPrint('SettingsPersistence.load: $error');
    }
    return <String, dynamic>{};
  }

  Future<void> save(Map<String, dynamic> values) async {
    final File? file = await _ensureFile();
    if (file == null) return;
    try {
      final File tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(values), flush: true);
      await tmp.rename(file.path);
    } catch (error) {
      debugPrint('SettingsPersistence.save: $error');
    }
  }
}
