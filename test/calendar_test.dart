import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:growza/calendar_data.dart';
import 'package:growza/calendar_feed.dart';
import 'package:growza/calendar_notifications.dart';
import 'package:growza/calendar_repository.dart';
import 'package:growza/calendar_service.dart';
import 'package:growza/study_data.dart';
import 'package:growza/exam_calendar.dart';
import 'package:growza/study_planner.dart';

String calendar(String components) =>
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Istudy Test//EN\r\n$components\r\nEND:VCALENDAR';
String event(String uid, String fields) =>
    'BEGIN:VEVENT\r\nUID:$uid\r\nDTSTAMP:20261101T000000Z\r\n$fields\r\nEND:VEVENT';
String todo(String uid, String fields) =>
    'BEGIN:VTODO\r\nUID:$uid\r\nDTSTAMP:20261101T000000Z\r\n$fields\r\nEND:VTODO';

class FakeCalendarNotifications extends CalendarNotifications {
  final queued = <int, ({CalendarReminder reminder, DateTime at})>{};
  final changes = <({bool added, List<CalendarItem> items})>[];
  bool allowed = true;
  @override
  Future<void> initialize({VoidCallback? onOpen}) async {}
  @override
  Future<bool> permitted() async => allowed;
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<Map<int, String?>> pending() async => {
    for (final id in queued.keys) id: 'calendar:test',
  };
  @override
  Future<void> cancel(int id) async {
    queued.remove(id);
  }

  @override
  Future<void> schedule(CalendarReminder reminder, DateTime at) async {
    queued[reminder.id] = (reminder: reminder, at: at);
  }

  @override
  Future<void> showChanges(
    List<CalendarItem> items, {
    required bool added,
  }) async {
    if (items.isNotEmpty) changes.add((added: added, items: items));
  }
}

void main() {
  final now = DateTime(2026, 11, 11, 10);
  setUpAll(() {
    sqfliteFfiInit();
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
  });

  test(
    'UTC, TZID, folded text and date-only tasks retain correct deadlines',
    () {
      final feed = calendar(
        [
          event(
            'utc',
            'DTSTART:20261112T150000Z\r\nSUMMARY:Assignment\\, part 1\r\n continued',
          ),
          todo(
            'zoned',
            'DUE;TZID=Asia/Riyadh:20261112T180000\r\nSUMMARY:Physics',
          ),
          todo('date', 'DUE;VALUE=DATE:20261112\r\nSUMMARY:Reading'),
        ].join('\r\n'),
      );
      final parsed = parseCalendar(feed, CalendarKind.deadlines, now);
      expect(parsed.skipped, 0);
      expect(parsed.items, hasLength(3));
      final utc = parsed.items.firstWhere((item) => item.uid == 'utc');
      expect(utc.title, 'Assignment, part 1continued');
      expect(utc.start.toUtc(), DateTime.utc(2026, 11, 12, 15));
      expect(
        parsed.items.firstWhere((item) => item.uid == 'zoned').start.toUtc(),
        utc.start.toUtc(),
      );
      final allDay = parsed.items.firstWhere((item) => item.uid == 'date');
      expect(allDay.dateOnly, isTrue);
      expect(allDay.start.day, 12);
      expect(calendarReminders([allDay], now).map((r) => r.kind), [1]);
    },
  );

  test(
    'weekly recurrences handle excluded and moved occurrences across DST',
    () {
      final feed = calendar(
        [
          event(
            'class',
            'DTSTART;TZID=America/New_York:20261025T100000\r\nDTEND;TZID=America/New_York:20261025T110000\r\nRRULE:FREQ=WEEKLY;COUNT=4\r\nEXDATE;TZID=America/New_York:20261108T100000\r\nSUMMARY:Lecture',
          ),
          event(
            'class',
            'RECURRENCE-ID;TZID=America/New_York:20261115T100000\r\nDTSTART;TZID=America/New_York:20261116T120000\r\nDTEND;TZID=America/New_York:20261116T130000\r\nSUMMARY:Moved lecture',
          ),
        ].join('\r\n'),
      );
      final parsed = parseCalendar(
        feed,
        CalendarKind.classes,
        DateTime(2026, 10, 25),
      );
      expect(parsed.skipped, 0);
      expect(parsed.items, hasLength(3));
      expect(parsed.items[0].start.toUtc(), DateTime.utc(2026, 10, 25, 14));
      expect(parsed.items[1].start.toUtc(), DateTime.utc(2026, 11, 1, 15));
      expect(parsed.items[2].start.toUtc(), DateTime.utc(2026, 11, 16, 17));
      expect(parsed.items.every((item) => !item.deadline), isTrue);
    },
  );

  test(
    'subscription links are normalized and HTML sign-in pages are rejected',
    () async {
      expect(
        calendarUri('webcal://campus.example/ical?token=abc').toString(),
        'https://campus.example/ical?token=abc',
      );
      expect(
        () => calendarUri('http://campus.example'),
        throwsA(isA<CalendarImportException>()),
      );
      final feed = CalendarFeed(
        client: MockClient(
          (request) async => http.Response('<html>Sign in</html>', 200),
        ),
      );
      await expectLater(
        feed.fetch('https://campus.example/ical', CalendarKind.deadlines, now),
        throwsA(isA<CalendarImportException>()),
      );
    },
  );

  test('cancelled events are removed and unknown timezones are reported', () {
    final parsed = parseCalendar(
      calendar(
        [
          event(
            'cancel',
            'DTSTART:20261112T120000Z\r\nSTATUS:CANCELLED\r\nSUMMARY:Cancelled',
          ),
          event(
            'badzone',
            'DTSTART;TZID=Unknown/Zone:20261112T120000\r\nSUMMARY:Unknown',
          ),
          event('okay', 'DTSTART:20261112T120000Z\r\nSUMMARY:Keep'),
        ].join('\r\n'),
      ),
      CalendarKind.deadlines,
      now,
    );
    expect(parsed.items.map((item) => item.uid), ['okay']);
    expect(parsed.skipped, 1);
  });

  test('mixed calendars distinguish classes from deadlines and accept a corrected type', () async {
    final preview = parseCalendar(
      calendar(
        [
          event(
            'class',
            'DTSTART:20261112T080000Z\r\nDTEND:20261112T090000Z\r\nSUMMARY:Physics lecture',
          ),
          event('work', 'DTSTART:20261112T150000Z\r\nSUMMARY:Essay deadline'),
        ].join('\r\n'),
      ),
      CalendarKind.mixed,
      now,
    );
    expect(preview.items.first.deadline, isFalse);
    expect(preview.items.last.deadline, isTrue);
    final repository = CalendarRepository(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    final engine = CalendarEngine(
      repository: repository,
      notifications: FakeCalendarNotifications(),
      now: () => now,
    );
    await engine.initialize();
    await engine.subscribe(
      'شامل',
      'https://campus.example/ical',
      CalendarKind.mixed,
      preview,
    );
    final item = (await repository.items()).first;
    await engine.setDeadline(item, true);
    await repository.storePreview(
      (await repository.sources()).single.id,
      preview,
      now,
    );
    expect((await repository.items()).first.deadline, isTrue);
    await repository.setRemindersEnabled(true);
    await engine.setSourceReminders(
      (await repository.sources()).single.id,
      false,
    );
    expect(await repository.items(remindersOnly: true), isEmpty);
    expect(await repository.items(), hasLength(2));
  });

  test('sync preserves completion, deduplicates, replaces reminders and reports new work', () async {
    final repository = CalendarRepository(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    final notifications = FakeCalendarNotifications();
    var body = calendar(
      event('one', 'DTSTART:20261112T150000Z\r\nSUMMARY:Essay'),
    );
    final feed = CalendarFeed(
      client: MockClient((request) async => http.Response(body, 200)),
    );
    final engine = CalendarEngine(
      repository: repository,
      feed: feed,
      notifications: notifications,
      now: () => now,
    );
    await engine.initialize();
    await repository.setRemindersEnabled(true);
    await engine.subscribe(
      'Blackboard',
      'https://campus.example/ical',
      CalendarKind.deadlines,
      await feed.fetch(
        'https://campus.example/ical',
        CalendarKind.deadlines,
        now,
      ),
    );
    expect(notifications.queued, hasLength(2));
    final original = (await repository.items()).single;
    await engine.refreshAll();
    expect(await repository.items(), hasLength(1));
    expect(notifications.changes, isEmpty);

    body = calendar(
      [
        event('one', 'DTSTART:20261113T150000Z\r\nSUMMARY:Essay'),
        event('two', 'DTSTART:20261114T160000Z\r\nSUMMARY:New homework'),
      ].join('\r\n'),
    );
    await engine.refreshAll();
    final updated = (await repository.items()).first;
    expect(updated.id, original.id);
    expect(
      notifications.queued[updated.id * 3 + 2]!.reminder.item.start.day,
      13,
    );
    expect(
      notifications.changes
          .where((change) => change.added)
          .single
          .items
          .single
          .title,
      'New homework',
    );

    await engine.markDone(updated, true);
    expect(notifications.queued.keys, isNot(contains(updated.id * 3 + 2)));
    await engine.refreshAll();
    expect((await repository.items()).first.done, isTrue);
    body = calendar('');
    await engine.refreshAll();
    expect(await repository.items(), isEmpty);
    expect(notifications.queued, isEmpty);
  });

  test('failed refresh retains imported data and delivered reminders are not repeated', () async {
    final repository = CalendarRepository(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    final notifications = FakeCalendarNotifications();
    var clock = now;
    var fail = false;
    final body = calendar(
      event('soon', 'DTSTART:20261111T110000\r\nSUMMARY:Due soon'),
    );
    final feed = CalendarFeed(
      client: MockClient(
        (request) async =>
            http.Response(fail ? '<html>Login</html>' : body, 200),
      ),
    );
    final engine = CalendarEngine(
      repository: repository,
      feed: feed,
      notifications: notifications,
      now: () => clock,
    );
    await engine.initialize();
    await repository.setRemindersEnabled(true);
    await engine.subscribe(
      'BB',
      'https://campus.example/feed',
      CalendarKind.deadlines,
      parseCalendar(body, CalendarKind.deadlines, clock),
    );
    expect(notifications.queued, hasLength(2));
    notifications.queued.clear();
    clock = now.add(const Duration(minutes: 1));
    await notifications.reconcile(repository, clock);
    expect(notifications.queued, isEmpty);
    fail = true;
    expect(await engine.refreshAll(), isFalse);
    expect(await repository.items(), hasLength(1));
    expect((await repository.sources()).single.error, isNotNull);
    await engine.remove((await repository.sources()).single.id);
    expect(await repository.sources(), isEmpty);
    expect(await repository.items(), isEmpty);
  });

  test(
    'calendar operations serialize foreground and background updates',
    () async {
      final repository = CalendarRepository(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(repository.close);
      final order = <String>[];
      final started = Completer<void>();
      final release = Completer<void>();
      final first = repository.withLock(() async {
        order.add('first');
        started.complete();
        await release.future;
        order.add('first done');
      });
      await started.future;
      final second = repository.withLock(() async {
        order.add('second');
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(order, ['first']);
      release.complete();
      await Future.wait([first, second]);
      expect(order, ['first', 'first done', 'second']);
    },
  );

  test('Manual exams schedule without subscriptions and edits replace their alarms', () async {
    final repository = CalendarRepository(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    final alerts = FakeCalendarNotifications();
    var subjects = [StudySubject('Math', DateTime(2026, 11, 14, 14), [])];
    final engine = CalendarEngine(
      repository: repository,
      notifications: alerts,
      now: () => now,
      examLoader: () async => subjects,
    );
    await engine.initialize();
    await engine.setReminders(true);
    expect(await repository.sources(), isEmpty);
    expect(alerts.queued, hasLength(3));
    expect(alerts.queued.keys.every((id) => id < 0), isTrue);
    final ids = alerts.queued.keys.toSet();
    subjects = [StudySubject('Math', DateTime(2026, 11, 15, 16), [])];
    await engine.updateReminders();
    expect(alerts.queued.keys.toSet(), ids);
    expect(
      alerts.queued.values.every(
        (entry) => entry.reminder.item.start == subjects.single.exam,
      ),
      isTrue,
    );
    await engine.setReminders(false);
    expect(alerts.queued, isEmpty);
    await engine.setReminders(true);
    expect(alerts.queued, hasLength(3));
    subjects = [];
    await engine.updateReminders();
    expect(alerts.queued, isEmpty);
    expect(await repository.reminders(), isEmpty);
  });

  test('Date-only exams have two reminders and no outdated tomorrow alert', () {
    final exam = examCalendarItems([
      StudySubject('Math', DateTime(2026, 11, 14), []),
    ]);
    expect(calendarReminders(exam, now).map((r) => r.kind), [0, 1]);
    expect(
      calendarReminders(exam, DateTime(2026, 11, 13, 10)).map((r) => r.kind),
      [1],
    );
    expect(calendarReminders(exam, DateTime(2026, 11, 15)), isEmpty);
    expect(
      examCalendarItems([StudySubject('Math', DateTime(2026, 11, 18), [])])
          .single
          .id,
      exam.single.id,
    );
  });

  test(
    'Imported dates become locally complete only after their calendar day ends',
    () {
      final yesterday = CalendarItem(
        uid: 'old',
        title: 'Old work',
        start: DateTime(2026, 11, 13, 23, 59),
      );
      expect(
        yesterday.completedAt(DateTime(2026, 11, 13, 23, 59, 59)),
        isFalse,
      );
      expect(yesterday.completedAt(DateTime(2026, 11, 14)), isTrue);
      expect(yesterday.done, isFalse);
      final today = CalendarItem(
        uid: 'today',
        title: 'Due earlier today',
        start: DateTime(2026, 11, 14, 8),
      );
      expect(today.completedAt(DateTime(2026, 11, 14, 18)), isFalse);
      expect(today.isPast(DateTime(2026, 11, 14, 18)), isTrue);
      final allDay = CalendarItem(
        uid: 'all-day',
        title: 'التاريخ فقط',
        start: DateTime(2026, 11, 13),
        dateOnly: true,
      );
      expect(allDay.completedAt(DateTime(2026, 11, 14)), isTrue);
      final continuing = CalendarItem(
        uid: 'continuing',
        title: 'Multi-day class',
        start: DateTime(2026, 11, 13, 9),
        end: DateTime(2026, 11, 15),
        deadline: false,
      );
      expect(continuing.completedAt(DateTime(2026, 11, 14, 18)), isFalse);
      expect(continuing.completedAt(DateTime(2026, 11, 15)), isTrue);
      final moved = CalendarItem(
        uid: 'old',
        title: 'Rescheduled work',
        start: DateTime(2026, 11, 16),
      );
      expect(moved.completedAt(DateTime(2026, 11, 14)), isFalse);
    },
  );

  test('imported class blocks are respected by study planning', () {
    final plan = StudyPlan.fit(
      tasks: pendingTasks([
        StudySubject('Math', DateTime(2026, 11, 12), [
          const StudyPart(1, 'Practice', 25),
        ]),
      ]),
      sessions: [],
      now: now,
      start: now,
      end: now.add(const Duration(hours: 2)),
      blocked: [(start: now, end: now.add(const Duration(hours: 1)))],
    );
    expect(plan.scheduled.single.start, now.add(const Duration(hours: 1)));
  });
}
