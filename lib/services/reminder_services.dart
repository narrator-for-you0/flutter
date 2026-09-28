import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the end-of-day "did you log today's spending?" reminder.
///
/// How it works: the app schedules one notification per evening for the next
/// [_daysAhead] days. Whenever an expense is logged today, [sync] is called
/// again and today's notification is simply not re-created, so the reminder
/// only ever fires on days with nothing logged. Every app launch refreshes
/// the window.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Sync calls run one at a time so a cancel from one can't interleave with
  // the scheduling of another.
  Future<void> _queue = Future.value();

  static const int _baseId = 9100; // uses ids 9100 .. 9100 + _daysAhead - 1
  static const int _daysAhead = 7;

  Future<void> _init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      final windowsSettings = WindowsInitializationSettings(
        appName: 'Food Allowance Tracker',
        appUserModelId: 'com.foodallowance.tracker',
        guid: 'b7e3c2a4-5d1f-4c8e-9a36-2f0d8e6b1c47',
      );
      await _plugin.initialize(
        settings: InitializationSettings(
          android: androidSettings,
          windows: windowsSettings,
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Reminder service could not start: $e');
    }
  }

  /// Asks for notification permission (Android 13+ shows a prompt; Windows
  /// has none). Returns false if the person said no.
  Future<bool> requestPermission() async {
    await _init();
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Reminder permission request failed: $e');
      return false;
    }
  }

  /// Re-creates the upcoming reminders. Call after anything that changes
  /// whether today has an expense, or when the settings change.
  Future<void> sync({
    required bool enabled,
    required TimeOfDay time,
    required bool loggedToday,
  }) {
    _queue = _queue.then((_) => _doSync(enabled, time, loggedToday));
    return _queue;
  }

  Future<void> _doSync(bool enabled, TimeOfDay time, bool loggedToday) async {
    await _init();
    if (!_ready) return;
    try {
      for (var i = 0; i < _daysAhead; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
      if (!enabled) return;

      final now = DateTime.now();
      final details = NotificationDetails(
        android: const AndroidNotificationDetails(
          'daily_log_reminder',
          'Daily spending reminder',
          channelDescription: "Reminds you to log the day's spending",
          importance: Importance.high,
          priority: Priority.high,
        ),
        windows: WindowsNotificationDetails(),
      );

      for (var i = 0; i < _daysAhead; i++) {
        if (i == 0 && loggedToday) continue; // already logged: no nudge tonight
        final when = DateTime(now.year, now.month, now.day + i, time.hour, time.minute);
        if (!when.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          id: _baseId + i,
          title: "Did you log today's spending?",
          body: 'Add what you spent today so your budget stays accurate.',
          // `when` is device-local wall time; converting the instant keeps
          // it correct no matter what tz.local is set to.
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }
}