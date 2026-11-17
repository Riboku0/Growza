import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growza/study_database.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';
import 'package:growza/growth_rules.dart';
import 'package:growza/growth_ledger.dart';
import 'package:growza/focus_record.dart';

String fixture() {
  final subject = StudySubject('التكامل Calculus II', DateTime(2026, 12, 1), [
    const StudyPart(
      7,
      'Integration',
      45,
      completed: true,
      startPage: 2,
      endPage: 12,
    ),
  ]);
  final start = DateTime(2026, 11, 15, 10);
  return const StudyStorage().encode(
    StudyWorkspace(
      subjects: [subject],
      sessions: [
        StudySession(
          subject.name,
          'Integration',
          start,
          25,
          partId: 7,
          completed: true,
          fixed: true,
        ),
      ],
      growth: GrowthLedger([
        FocusRecord(
          id: 'stable',
          subjectId: subject.id,
          planned: const Duration(minutes: 25),
          endedAt: start.add(const Duration(minutes: 10)),
          spans: [FocusSpan(start, start.add(const Duration(minutes: 10)))],
          completed: false,
          quality: FocusQuality.half,
        ),
      ]),
      darkMode: true,
      languageCode: 'en',
      focusCount: 3,
      pendingFocusReviewId: 'stable',
      recentSubjects: [subject.name],
      activeTimer: {'example': 'opaque snapshot'},
    ),
  );
}

String normalize(String? raw) => const StudyStorage().encode(
  raw == null ? StudyWorkspace() : const StudyStorage().decode(raw),
);
void main() {
  setUpAll(sqfliteFfiInit);
  test('Normalized SQLite preserves subjects, topics, quality, spans, counters, preferences and timer', () async {
    final store = StudyDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final original = fixture();
    final result = await store.readOrMigrate(
      readLegacy: () async => original,
      normalize: normalize,
    );
    expect(jsonDecode(result), jsonDecode(original));
    final db = await store.database;
    expect((await db.query('subjects')).single['name'], 'التكامل Calculus II');
    expect((await db.query('focus_sessions')).single['quality'], 'half');
    expect((await db.query('topics')).single['id'], 7);
    expect(await db.query('focus_spans'), hasLength(1));
  });
  test('Old JSON without IDs and quality migrates exactly once and survives reopening', () async {
    final folder = await Directory.systemTemp.createTemp('growza-sql-test');
    addTearDown(() => folder.delete(recursive: true));
    final path = '${folder.path}/study.db';
    final old = jsonDecode(fixture()) as Map<String, dynamic>;
    old['subjects'][0].remove('id');
    old.remove('growth');
    final legacy = jsonEncode(old);
    var calls = 0;
    var store = StudyDatabase(factory: databaseFactoryFfi, path: path);
    final first = await store.readOrMigrate(
      readLegacy: () async {
        calls++;
        return legacy;
      },
      normalize: normalize,
    );
    final id = jsonDecode(first)['subjects'][0]['id'];
    await store.close();
    store = StudyDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(store.close);
    final second = await store.readOrMigrate(
      readLegacy: () async {
        calls++;
        return legacy;
      },
      normalize: normalize,
    );
    expect(jsonDecode(second)['subjects'][0]['id'], id);
    expect(calls, 1);
    expect(jsonDecode(second), jsonDecode(first));
  });
  test('Malformed legacy file never initializes an empty replacement and can be retried', () async {
    final store = StudyDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    await expectLater(
      store.readOrMigrate(
        readLegacy: () async => 'broken-json',
        normalize: normalize,
      ),
      throwsFormatException,
    );
    expect(await (await store.database).query('workspace_meta'), isEmpty);
    final recovered = await store.readOrMigrate(
      readLegacy: () async => fixture(),
      normalize: normalize,
    );
    expect(jsonDecode(recovered)['subjects'], hasLength(1));
  });
  test(
    'Failed write rolls back every table and leaves previous workspace intact',
    () async {
      final store = StudyDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(store.close);
      final first = await store.readOrMigrate(
        readLegacy: () async => fixture(),
        normalize: normalize,
      );
      final invalid = jsonDecode(first) as Map<String, dynamic>;
      invalid['subjects'].add(invalid['subjects'][0]);
      await expectLater(
        store.write(jsonEncode(invalid)),
        throwsA(isA<DatabaseException>()),
      );
      final after = await store.readOrMigrate(
        readLegacy: () async => null,
        normalize: normalize,
      );
      expect(jsonDecode(after), jsonDecode(first));
    },
  );
  test('Deleted-subject focus history remains stored without a subject foreign key', () async {
    final store = StudyDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final value = jsonDecode(fixture()) as Map<String, dynamic>;
    value['subjects'] = [];
    await store.write(jsonEncode(value));
    final saved = jsonDecode(
      await store.readOrMigrate(
        readLegacy: () async => null,
        normalize: normalize,
      ),
    );
    expect(saved['growth']['records'][0]['id'], 'stable');
    expect(saved['subjects'], isEmpty);
  });
  test(
    'Concurrent migration callers keep one stable imported workspace',
    () async {
      final store = StudyDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(store.close);
      var calls = 0;
      final results = await Future.wait(
        List.generate(
          5,
          (_) => store.readOrMigrate(
            readLegacy: () async {
              calls++;
              return fixture();
            },
            normalize: normalize,
          ),
        ),
      );
      expect(calls, 1);
      for (final result in results) {
        expect(jsonDecode(result), jsonDecode(results.first));
      }
    },
  );

  test('Version 1 migration preserves all rows and links old page ranges to their original PDF', () async {
    final folder = await Directory.systemTemp.createTemp('growza-upgrade-test');
    addTearDown(() => folder.delete(recursive: true));
    final path = '${folder.path}/study.db';
    var store = StudyDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(() => store.close());
    final data = jsonDecode(fixture()) as Map<String, dynamic>;
    data['subjects'][0]['pdfName'] = 'legacy.pdf';
    await store.write(jsonEncode(data));
    final oldDb = await store.database;
    await oldDb.execute('ALTER TABLE topics DROP COLUMN pdf_name');
    await oldDb.execute('PRAGMA user_version = 1');
    await store.close();
    store = StudyDatabase(factory: databaseFactoryFfi, path: path);
    final restored = jsonDecode(
      await store.readOrMigrate(
        readLegacy: () async => null,
        normalize: normalize,
      ),
    );
    expect(restored['subjects'][0]['parts'][0]['id'], 7);
    expect(restored['subjects'][0]['parts'][0]['completed'], isTrue);
    expect(restored['subjects'][0]['parts'][0]['pdfName'], 'legacy.pdf');
    expect(restored['growth']['records'], data['growth']['records']);
    expect(restored['sessions'], data['sessions']);
    expect(restored['activeTimer'], data['activeTimer']);
    expect(
      (await (await store.database).rawQuery('PRAGMA integrity_check'))
          .single
          .values
          .single,
      'ok',
    );
  });
}
