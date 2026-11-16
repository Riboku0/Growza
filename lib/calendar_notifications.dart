import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_data.dart';
import 'calendar_repository.dart';
import 'study_data.dart';

class CalendarReminder {
  const CalendarReminder(
    this.item,
    this.kind,
    this.nominal,
    this.title, {
    this.languageCode = 'ar',
  });
  final String languageCode;
  final CalendarItem item;
  final int kind;
  final DateTime nominal;
  final String title;
  int get id => item.id * 3 + kind;
  String get signature =>
      '${item.dateKey}|${item.title}|${item.deadline}|$kind|${nominal.toUtc().toIso8601String()}|$languageCode-v2';
}

List<CalendarReminder> calendarReminders(
  List<CalendarItem> items,
  DateTime now, {
  String languageCode = 'ar',
}) {
  final result = <CalendarReminder>[];
  for (final item in items) {
    if (item.completedAt(now) || item.isPast(now)) continue;
    final start = item.start;
    final exam = item.sourceId == -1;
    if (exam) {
      final previous = item.dateOnly
          ? DateTime(start.year, start.month, start.day - 1, 9)
          : start.subtract(const Duration(days: 1));
      if (previous.isAfter(now)) {
        result.add(CalendarReminder(item, 0, previous, 'الاختبار غداً'));
      }
    }
    final today = DateTime(
      start.year,
      start.month,
      start.day,
      !item.dateOnly && start.hour < 9 ? 0 : 9,
    );
    result.add(
      CalendarReminder(
        item,
        1,
        today,
        exam
            ? 'الاختبار اليوم'
            : item.deadline
            ? 'التسليم اليوم'
            : 'محاضرة اليوم',
      ),
    );
    if (!item.dateOnly) {
      result.add(
        CalendarReminder(
          item,
          2,
          start.subtract(const Duration(hours: 1)),
          exam
              ? 'الاختبار خلال ساعة'
              : item.deadline
              ? 'التسليم خلال ساعة'
              : 'تبدأ المحاضرة خلال ساعة',
        ),
      );
    }
  }
  if (languageCode == 'en') {
    return result
        .map(
          (r) => CalendarReminder(
            r.item,
            r.kind,
            r.nominal,
            {
                  'الاختبار غداً': 'Exam tomorrow',
                  'الاختبار اليوم': 'Exam today',
                  'التسليم اليوم': 'Due today',
                  'محاضرة اليوم': 'Class today',
                  'الاختبار خلال ساعة': 'Exam in one hour',
                  'التسليم خلال ساعة': 'Due in one hour',
                  'تبدأ المحاضرة خلال ساعة': 'Class starts in one hour',
                }[r.title] ??
                r.title,
            languageCode: 'en',
          ),
        )
        .toList();
  }
  return result;
}

class CalendarNotifications {
  String languageCode = 'ar';
  final _plugin = FlutterLocalNotificationsPlugin();
  DateTime? openedDate;
  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'istudy_calendar_deadlines',
      'تنبيهات التقويم',
      channelDescription: 'الاختبارات والتسليمات والمحاضرات وتحديثات التقويم',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_study',
      visibility: NotificationVisibility.private,
    ),
    iOS: DarwinNotificationDetails(),
  );

  NotificationDetails get localizedDetails => languageCode == 'en'
      ? const NotificationDetails(
          android: AndroidNotificationDetails(
            'istudy_calendar_deadlines',
            'Calendar reminders',
            channelDescription:
                'Exams, deadlines, classes and calendar updates',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_study',
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(),
        )
      : details;

  Future<void> initialize({VoidCallback? onOpen}) async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Scheduled instants use UTC. Floating feed times use Dart's local clock.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_study'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload?.startsWith('calendar:') ?? false) {
          openedDate = DateTime.tryParse(response.payload!.split('|').last);
          onOpen?.call();
        }
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        (launch?.notificationResponse?.payload?.startsWith('calendar:') ??
            false)) {
      openedDate = DateTime.tryParse(
        launch!.notificationResponse!.payload!.split('|').last,
      );
      onOpen?.call();
    }
  }

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<bool> permitted() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    return (await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ??
        false;
  }

  Future<Map<int, String?>> pending() async => {
    for (final notification in await _plugin.pendingNotificationRequests())
      if (notification.payload?.startsWith('calendar:') ?? false)
        notification.id: notification.payload,
  };

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> schedule(CalendarReminder reminder, DateTime at) async {
    await _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      '${reminder.item.title} · ${reminder.item.dateOnly ? (languageCode == 'en' ? 'All day' : 'طوال اليوم') : clockLabel(reminder.item.start)} · ${reminder.item.sourceName}',
      tz.TZDateTime.from(at, tz.UTC),
      localizedDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload:
          'calendar:${reminder.item.id}|${reminder.item.start.toIso8601String()}',
    );
  }

  Future<void> showChanges(
    List<CalendarItem> items, {
    required bool added,
  }) async {
    if (items.isEmpty || !await permitted()) return;
    final first = items.first;
    await _plugin.show(
      first.id * 3,
      languageCode == 'en'
          ? (added ? 'New calendar items' : 'Calendar updated')
          : (added ? 'عناصر جديدة في التقويم' : 'حُدّث التقويم'),
      items.length == 1
          ? '${first.title} · ${first.sourceName}'
          : (languageCode == 'en'
                ? '${items.length} calendar items. Open Schedule to review them.'
                : 'عناصر في تقاويمك: ${items.length}. افتح الجدول لمراجعتها.'),
      localizedDetails,
      payload: 'calendar:${first.id}|${first.start.toIso8601String()}',
    );
  }

  Future<void> reconcile(
    CalendarRepository repository,
    DateTime now, {
    List<CalendarItem> exams = const [],
  }) async {
    final enabled = await repository.remindersEnabled() && await permitted();
    final saved = await repository.reminders();
    final pendingIds = await pending();
    final reminders = enabled
        ? calendarReminders(
            [...await repository.items(remindersOnly: true), ...exams],
            now,
            languageCode: languageCode,
          )
        : <CalendarReminder>[];
    final valid = {for (final reminder in reminders) reminder.id: reminder};
    final schedules = <({CalendarReminder reminder, DateTime at})>[];
    for (final reminder in reminders) {
      final previous = saved[reminder.id];
      if (previous?['signature'] == reminder.signature) {
        final at = DateTime.fromMillisecondsSinceEpoch(previous!['at'] as int);
        if (!at.isAfter(now)) continue;
        schedules.add((reminder: reminder, at: at));
      } else {
        final at = reminder.nominal.isAfter(now)
            ? reminder.nominal
            : now.add(const Duration(seconds: 5));
        schedules.add((reminder: reminder, at: at));
      }
    }
    schedules.sort((a, b) => a.at.compareTo(b.at));
    // iOS allows 64 pending requests. Keep the nearest 60 on both mobile platforms.
    final nearest = schedules.take(60).toList();
    final wanted = nearest.map((entry) => entry.reminder.id).toSet();
    for (final id in {...saved.keys, ...pendingIds.keys}) {
      final reminder = valid[id];
      if (reminder == null || saved[id]?['signature'] != reminder.signature) {
        await cancel(id);
        await repository.removeReminder(id);
      } else if (pendingIds.containsKey(id) && !wanted.contains(id)) {
        await cancel(id);
      }
    }
    for (final entry in nearest) {
      final reminder = entry.reminder;
      if (saved[reminder.id]?['signature'] == reminder.signature &&
          pendingIds.containsKey(reminder.id)) {
        continue;
      }
      await schedule(reminder, entry.at);
      await repository.rememberReminder(
        reminder.id,
        reminder.signature,
        entry.at,
      );
    }
  }
}
