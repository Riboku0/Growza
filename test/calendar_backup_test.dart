import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growza/calendar_data.dart';
import 'package:growza/calendar_repository.dart';
import 'package:growza/calendar_notifications.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('Calendar backup restores sources and event flags offline and merges without duplicates', () async {
    final source = CalendarRepository(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(source.close);
    final id = await source.addSource(
      'Campus',
      'https://campus.example.test/private',
      CalendarKind.deadlines,
    );
    await source.storePreview(
      id,
      CalendarPreview('Campus', [
        CalendarItem(
          uid: 'task',
          title: 'Homework',
          start: DateTime(2026, 12, 1),
        ),
      ]),
      DateTime(2026, 11, 15),
    );
    final item = (await source.items()).single;
    await source.markDone(item.id, true);
    final data = await source.backupSnapshot();
    CalendarRepository.validateBackup(data);
    final restored = CalendarRepository(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(restored.close);
    await restored.withLock(() => restored.restoreBackup(data, replace: true));
    expect((await restored.items()).single.done, true);
    await restored.withLock(() => restored.restoreBackup(data, replace: false));
    expect(await restored.sources(), hasLength(1));
    expect(await restored.items(), hasLength(1));
    final bad = {
      ...data,
      'events': [
        {'id': 99},
      ],
    };
    await expectLater(
      restored.restoreBackup(bad, replace: true),
      throwsA(anything),
    );
    expect((await restored.items()).single.done, true);
  });
  test('Notification language changes titles and signature but preserves reminder identities', () {
    final item = CalendarItem(
      id: 4,
      uid: 'task',
      title: 'Homework',
      start: DateTime(2026, 12, 1, 14),
    );
    final now = DateTime(2026, 11, 30);
    final ar = calendarReminders([item], now);
    final en = calendarReminders([item], now, languageCode: 'en');
    expect(en.map((r) => r.id), ar.map((r) => r.id));
    expect(en.first.title, 'Due today');
    expect(en.first.signature, isNot(ar.first.signature));
  });
}
