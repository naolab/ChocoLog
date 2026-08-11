import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  ReminderService._();

  static final instance = ReminderService._();
  static const _firstNotificationId = 7100;

  final _notifications = FlutterLocalNotificationsPlugin();
  var _initialized = false;

  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  Future<bool> scheduleWeekly({
    required List<int> weekdays,
    required int hour,
    required int minute,
    bool requestPermission = false,
  }) async {
    try {
      await initialize();
      if (!_initialized) return false;
      if (requestPermission && !await _requestPermission()) return false;
      await cancelWeekly();
      for (final (index, weekday) in weekdays.indexed) {
        await _notifications.zonedSchedule(
          id: _firstNotificationId + index,
          title: 'トレーニングの時間です',
          body: '今日のメニューをChocoLogに記録しましょう',
          scheduledDate: _nextWeekday(weekday, hour, minute),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'weekly_reminder',
              '週間リマインダー',
              channelDescription: '設定した曜日にトレーニングをお知らせします',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '/home',
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelWeekly() async {
    if (!isSupported) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;
    try {
      for (var index = 0; index < 7; index++) {
        await _notifications.cancel(id: _firstNotificationId + index);
      }
    } catch (_) {
      // Notifications are optional and must never block workout recording.
    }
  }

  Future<bool> _requestPermission() async {
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    }
    if (Platform.isAndroid) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
