import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads real application icons through the native `timeflow/usage` channel.
///
/// Android resolves icons from PackageManager. Windows extracts the executable
/// icon from the shell / the stored executable path. Results are cached in
/// memory and nulls are cached as well, so missing icons never cause repeated
/// platform calls while scrolling.
abstract final class AppIcons {
  static const MethodChannel _channel = MethodChannel('timeflow/usage');

  static final Map<String, Uint8List?> _cache = <String, Uint8List?>{};
  static final Map<String, Future<Uint8List?>> _pending =
      <String, Future<Uint8List?>>{};
  static final Map<String, String> _paths = <String, String>{};
  static final Map<String, int> _versions = <String, int>{};

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;

  /// Remembers the executable path reported by live tracking so Windows can
  /// extract the icon without guessing.
  static void registerPath(String appId, String? path) {
    if (path == null || path.isEmpty) return;
    if (_paths[appId] == path) return;
    _paths[appId] = path;
    _versions[appId] = (_versions[appId] ?? 0) + 1;
    _cache.remove(appId);
    _pending.remove(appId);
  }

  static Future<Uint8List?> load(String appId) {
    if (!isSupported) return Future<Uint8List?>.value();
    if (_cache.containsKey(appId)) {
      return Future<Uint8List?>.value(_cache[appId]);
    }
    final Future<Uint8List?>? pending = _pending[appId];
    if (pending != null) return pending;

    final int version = _versions[appId] ?? 0;
    final String? path = _paths[appId];
    final Future<Uint8List?> future = _fetch(appId, path).then((
      Uint8List? bytes,
    ) {
      if ((_versions[appId] ?? 0) == version) {
        _cache[appId] = bytes;
      }
      return bytes;
    });
    _pending[appId] = future;
    future.whenComplete(() {
      if (identical(_pending[appId], future)) _pending.remove(appId);
    });
    return future;
  }

  static Future<Uint8List?> _fetch(String appId, String? path) async {
    try {
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>(
        'getAppIcon',
        <String, String>{
          'appId': appId,
          if (path != null && path.isNotEmpty) 'path': path,
        },
      );
      return bytes != null && bytes.isNotEmpty ? bytes : null;
    } on PlatformException catch (error) {
      debugPrint('getAppIcon($appId) failed: ${error.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
