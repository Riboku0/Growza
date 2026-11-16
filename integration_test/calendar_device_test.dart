import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import 'package:growza/calendar_data.dart';
import 'package:growza/calendar_notifications.dart';
import 'package:growza/calendar_repository.dart';
import 'package:growza/calendar_service.dart';
import 'package:growza/study_data.dart';

@pragma('vm:entry-point')
void testCalendarDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final repository = CalendarRepository(
      path: inputData!['database'] as String,
    );
    final engine = CalendarEngine(repository: repository);
    try {
      await engine.initialize();
      await engine.refreshAll();
      await (await repository.database).insert('settings', {
        'key': 'background-smoke',
        'value': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    } finally {
      await repository.close();
    }
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android imports persist and reminder alarms reconcile', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('GROWZA_VERIFICATION'), true);
    final path = '${await getDatabasesPath()}/istudy-calendar-device-test.db';
    await deleteDatabase(path);
    final repository = CalendarRepository(path: path);
    final alerts = CalendarNotifications();
    final now = DateTime.now();
    var subjects = <StudySubject>[];
    var language = 'ar';
    final engine = CalendarEngine(
      repository: repository,
      notifications: alerts,
      examLoader: () async => subjects,
      languageLoader: () async => language,
    );
    try {
      await engine.initialize();
      for (
        var attempt = 0;
        attempt < 60 && !await alerts.permitted();
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect(
        await alerts.permitted(),
        isTrue,
        reason: 'Grant POST_NOTIFICATIONS on the emulator.',
      );
      await repository.setRemindersEnabled(true);
      await engine.subscribe(
        'Device test',
        'https://calendar.example/test',
        CalendarKind.deadlines,
        CalendarPreview('Device test', [
          CalendarItem(
            uid: 'device-test',
            title: 'Test deadline',
            start: now.add(const Duration(minutes: 30)),
          ),
        ]),
      );
      expect(
        await alerts.permitted(),
        isTrue,
        reason: 'Grant POST_NOTIFICATIONS to the emulator before running this test.',
      );
      expect(await alerts.pending(), hasLength(2));
      final identities = (await alerts.pending()).keys.toSet();
      language = 'en';
      await engine.updateReminders();
      expect((await alerts.pending()).keys.toSet(), identities);
      final localized = await FlutterLocalNotificationsPlugin()
          .pendingNotificationRequests();
      expect(localized.any((r) => r.title == 'Due today'), true);
      final item = (await repository.items()).single;
      expect(item.title, 'Test deadline');
      expect((await repository.sources()).single.name, 'Device test');
      final reopened = CalendarRepository(path: path);
      try {
        expect((await reopened.items()).single.title, 'Test deadline');
      } finally {
        await reopened.close();
      }
      await alerts.showChanges([item], added: true);
      final active = await FlutterLocalNotificationsPlugin()
          .getActiveNotifications();
      expect(
        active.map((notification) => notification.id),
        contains(item.id * 3),
      );
      await engine.markDone(item, true);
      expect(await alerts.pending(), isEmpty);
      expect((await repository.items()).single.done, isTrue);
      await engine.markDone((await repository.items()).single, false);
      expect(await alerts.pending(), hasLength(2));
      await engine.remove((await repository.sources()).single.id);
      expect(await alerts.pending(), isEmpty);
      subjects = [
        StudySubject(
          'Native exam test',
          now.add(const Duration(days: 4, hours: 2)),
          [],
        ),
      ];
      await engine.updateReminders();
      expect(await alerts.pending(), hasLength(3));
      expect((await alerts.pending()).keys.every((id) => id < 0), isTrue);
      subjects = [
        StudySubject(
          'Native exam test',
          now.add(const Duration(days: 5, hours: 3)),
          [],
        ),
      ];
      await engine.updateReminders();
      expect(await alerts.pending(), hasLength(3));
      subjects = [];
      await engine.updateReminders();
      expect(await alerts.pending(), isEmpty);
      await Workmanager().initialize(testCalendarDispatcher);
      await Workmanager().registerOneOffTask(
        'istudy-calendar-device-test',
        'calendar-device-test',
        inputData: {'database': path},
      );
      var backgroundCompleted = false;
      for (var attempt = 0; attempt < 60 && !backgroundCompleted; attempt++) {
        final result = await (await repository.database).query(
          'settings',
          where: 'key = ?',
          whereArgs: ['background-smoke'],
        );
        backgroundCompleted = result.isNotEmpty;
        if (!backgroundCompleted) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      expect(
        backgroundCompleted,
        isTrue,
        reason: 'The background Flutter engine must initialize the native calendar services.',
      );
      await Workmanager().cancelByUniqueName('istudy-calendar-device-test');
      await Workmanager().initialize(calendarCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        calendarSyncTask,
        calendarSyncTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      expect(
        await Workmanager().isScheduledByUniqueName(calendarSyncTask),
        isTrue,
      );
      await Workmanager().cancelByUniqueName(calendarSyncTask);
      final service = CalendarService(background: false);
      await service.initialize();
      expect(service.supported, true);
      service.dispose();
    } finally {
      await repository.close();
      await deleteDatabase(path);
    }
  });
}
