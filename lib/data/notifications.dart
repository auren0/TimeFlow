import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Daily summary notifications for Android, Windows and Linux.
///
/// Android and Windows schedule native notifications. The Linux plugin has no
/// scheduler, so Linux uses an in-process timer while TimeFlow is running.
abstract final class DailyNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 4100;
  static const int _windowsDays = 30;

  static bool _initialized = false;
  static bool _available = true;
  static Timer? _linuxTimer;

  static Future<bool> initialize() async {
    if (_initialized) return _available;
    if (!_supported) return false;
    try {
      tz_data.initializeTimeZones();
      try {
        final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (error) {
        debugPrint('DailyNotifications: timezone lookup failed ($error)');
      }

      const InitializationSettings settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_timeflow'),
        linux: LinuxInitializationSettings(
          defaultActionName: 'Открыть TimeFlow',
        ),
        windows: WindowsInitializationSettings(
          appName: 'TimeFlow',
          appUserModelId: 'TimeFlow.App',
          guid: 'f3c1e0b8-5c7a-4f0f-9e1f-3b2c1a4d5e6f',
        ),
      );
      final bool? result = await _plugin.initialize(settings: settings);
      _available = result ?? true;
      _initialized = true;
    } catch (error) {
      debugPrint('DailyNotifications.initialize: $error');
      _available = false;
      _initialized = true;
    }
    return _available;
  }

  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  static Future<bool> requestPermission() async {
    if (!await initialize()) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (error) {
      debugPrint('DailyNotifications.requestPermission: $error');
      return false;
    }
  }

  static Future<void> schedule({
    required bool enabled,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    _linuxTimer?.cancel();
    _linuxTimer = null;
    if (!await initialize()) return;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('DailyNotifications.cancelAll: $error');
    }
    if (!enabled) return;

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_summary',
        'Ежедневная сводка',
        channelDescription: 'Итоги экранного времени за вчерашний день',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    try {
      if (defaultTargetPlatform == TargetPlatform.linux) {
        _armLinuxTimer(next, title, body, details);
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.windows) {
        for (int i = 0; i < _windowsDays; i++) {
          await _plugin.zonedSchedule(
            id: _notificationId + i,
            title: title,
            body: body,
            scheduledDate: next.add(Duration(days: i)),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
        return;
      }
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: title,
        body: body,
        scheduledDate: next,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      debugPrint('DailyNotifications.schedule: $error');
    }
  }

  static Future<void> showTest({
    required String title,
    required String body,
  }) async {
    if (!await initialize()) return;
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_summary',
        'Ежедневная сводка',
        channelDescription: 'Итоги экранного времени за вчерашний день',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
    try {
      await _plugin.show(
        id: _notificationId + 100,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (error) {
      debugPrint('DailyNotifications.showTest: $error');
    }
  }

  static void stopInProcessTimer() {
    _linuxTimer?.cancel();
    _linuxTimer = null;
  }

  static void _armLinuxTimer(
    tz.TZDateTime next,
    String title,
    String body,
    NotificationDetails details,
  ) {
    final Duration delay = next.difference(tz.TZDateTime.now(tz.local));
    _linuxTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      try {
        await _plugin.show(
          id: _notificationId,
          title: title,
          body: body,
          notificationDetails: details,
        );
      } catch (error) {
        debugPrint('DailyNotifications.linuxShow: $error');
      }
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime following = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        next.hour,
        next.minute,
      );
      if (!following.isAfter(now)) {
        following = following.add(const Duration(days: 1));
      }
      _armLinuxTimer(following, title, body, details);
    });
  }
}
