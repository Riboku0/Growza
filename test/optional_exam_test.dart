import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growza/main.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_database.dart';
import 'package:growza/study_planner.dart';
import 'package:growza/study_recommendation.dart';
import 'package:growza/exam_calendar.dart';
import 'package:growza/subject_setup.dart';
import 'package:growza/workspace_backup.dart';
import 'package:growza/exam_editor.dart';

import 'pdf_creation_flow_test.dart' as pdf;
import 'local_services_ui_test.dart' as ui;
import 'frontend_completion_test.dart' as flow;
import 'study_database_test.dart' as legacy;
import 'calendar_test.dart' as calendar;

import 'package:growza/calendar_service.dart';
import 'package:growza/calendar_repository.dart';

final now = DateTime(2026, 11, 17, 12);
StudySubject undated(String name) =>
    StudySubject(name, null, [const StudyPart(1, 'Topic', 25)]);
void main() {
  setUpAll(sqfliteFfiInit);
  test('Undated subjects round-trip JSON and backups, stay active and create no exam events', () {
    final subject = undated('Open learning');
    final workspace = StudyWorkspace(subjects: [subject]);
    final restored = const StudyStorage().decode(
      const StudyStorage().encode(workspace),
    );
    expect(restored.subjects.single.exam, isNull);
    final backup = WorkspaceBackup.parse(WorkspaceBackup.export(restored));
    expect(backup.subjects.single.exam, isNull);
    expect(backup.subjects.single.id, subject.id);
    expect(examCalendarItems(backup.subjects), isEmpty);
    expect(workspace.growthFor(subject, DateTime(2100)).harvested, isFalse);
    final raw = subject.toJson()..remove('exam');
    expect(StudySubject.fromJson(raw).exam, isNull);
  });
  test('Recommendations and planning accept undated study without inventing a cutoff', () {
    final a = undated('A'), b = undated('B');
    final dated = StudySubject('Exam', now.add(const Duration(days: 2)), [
      const StudyPart(1, 'Exam topic', 25),
    ]);
    expect(recommendSubject([a, b], ['B'], now), b);
    expect(recommendSubject([a, b, dated], ['B'], now), dated);
    final plan = StudyPlan.fit(
      tasks: pendingTasks([a]),
      sessions: [],
      now: now,
      start: now.add(const Duration(days: 10)),
      end: now.add(const Duration(days: 10, hours: 1)),
    );
    expect(plan.scheduled.single.subject, 'A');
    expect(plan.unscheduled, isEmpty);
  });
  test(
    'Removing the exam cancels its old reminders without deleting the subject',
    () async {
      final repository = CalendarRepository(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(repository.close);
      final alerts = calendar.FakeCalendarNotifications();
      var subjects = [
        StudySubject('Math', now.add(const Duration(days: 2, hours: 2)), [
          const StudyPart(1, 'Topic', 25),
        ]),
      ];
      final engine = CalendarEngine(
        repository: repository,
        notifications: alerts,
        now: () => now,
        examLoader: () async => subjects,
      );
      await engine.initialize();
      await engine.setReminders(true);
      expect(alerts.queued, isNotEmpty);
      expect(engine.examCount, 1);
      final subject = subjects.single;
      subjects = [
        StudySubject(subject.name, null, subject.parts, id: subject.id),
      ];
      await engine.updateReminders();
      expect(alerts.queued, isEmpty);
      expect(await repository.reminders(), isEmpty);
      expect(engine.examCount, 0);
      expect(subjects.single.parts, hasLength(1));
    },
  );
  testWidgets(
    'A subject can be created manually with no exam and shown without countdown or fake exam',
    (t) async {
      final store = flow.MemoryStorage();
      store.snapshot = store.encode(StudyWorkspace());
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: store, timerNow: () => now),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('أضف مادتك الأولى'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).at(0), 'Reading');
      await flow.tap(t, find.byType(TextFormField).at(1));
      await t.enterText(find.byType(TextFormField).at(1), 'Chapter one');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await flow.tap(t, find.text('حفظ المادة'));
      expect(store.decode(store.snapshot).subjects.single.exam, isNull);
      expect(find.byKey(const ValueKey('home-exam-countdown')), findsNothing);
      expect(find.text('حُفظت المادة.'), findsOneWidget);
      expect(find.text('مقترحة لقرب اختبارها'), findsNothing);
      await t.tap(find.text('المواد'));
      await t.pumpAndSettle();
      await flow.tap(t, find.byTooltip('خيارات Reading'));
      expect(find.text('إضافة اختبار'), findsOneWidget);
      expect(find.text('عرض الاختبار'), findsNothing);
      await t.tap(find.text('إضافة اختبار'));
      await t.pumpAndSettle();
      await flow.tap(t, find.text('اختر موعد الاختبار'));
      await t.tap(find.text('حسنًا'));
      await t.pumpAndSettle();
      await flow.tap(t, find.text('حفظ الاختبار'));
      final subject = store.decode(store.snapshot).subjects.single;
      expect(subject.exam, isNotNull);
      expect(examCalendarItems([subject]), hasLength(1));
      await flow.tap(t, find.byTooltip('خيارات Reading'));
      await t.tap(find.text('تعديل الاختبار'));
      await t.pumpAndSettle();
      await flow.tap(t, find.text('إزالة موعد الاختبار'));
      await flow.tap(t, find.text('حفظ الاختبار'));
      final cleared = store.decode(store.snapshot).subjects.single;
      expect(cleared.exam, isNull);
      expect(cleared.id, subject.id);
      expect(cleared.parts.single.title, 'Chapter one');
      expect(examCalendarItems([cleared]), isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'PDF suggestions can create an undated subject in the same form',
    (t) async {
      StudySubject? saved;
      await pdf.open(
        t,
        SubjectSetup(
          now: () => now,
          topicProvider: pdf.Topics(),
          pdfPicker: () async => pdf.selection,
        ),
        (s) => saved = s,
      );
      await t.enterText(find.byType(TextFormField).first, 'Biology');
      await pdf.consent(t);
      await ui.tap(t, find.text('حفظ المادة'));
      expect(saved!.exam, isNull);
      expect(saved!.parts, hasLength(2));
      expect(saved!.parts.first.pdfName, 'biology.pdf');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('An exam dated today may omit its clock time', (t) async {
    ExamSelection? saved;
    final subject = StudySubject(
      'Today',
      DateTime(now.year, now.month, now.day),
      [const StudyPart(1, 'Topic', 25)],
    );
    await t.pumpWidget(
      ui.host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                saved = await Navigator.of(context).push<ExamSelection>(
                  MaterialPageRoute(
                    builder: (_) => ExamEditor(subject: subject, now: now),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await ui.tap(t, find.text('حفظ الاختبار'));
    expect(saved!.date, subject.exam);
    expect(t.takeException(), isNull);
  });
  for (final version in [1, 2]) {
    test(
      'SQLite v$version upgrade keeps topics/history and makes the exam column genuinely nullable',
      () async {
        final folder = await Directory.systemTemp.createTemp(
          'growza-optional-exam',
        );
        addTearDown(() => folder.delete(recursive: true));
        final seed = StudyDatabase(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        );
        addTearDown(seed.close);
        final data = jsonDecode(legacy.fixture()) as Map<String, dynamic>;
        data['subjects'][0]['pdfName'] = 'notes.pdf';
        await seed.write(jsonEncode(data));
        final seedDb = await seed.database;
        final path = '${folder.path}/legacy.db';
        final old = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: version,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys=ON');
            },
            onCreate: (db, _) async {
              for (final sql in _legacySchema) {
                await db.execute(
                  version == 1
                      ? sql.replaceAll(
                          ', pdf_name TEXT, PRIMARY KEY',
                          ', PRIMARY KEY',
                        )
                      : sql,
                );
              }
            },
          ),
        );
        final before = <String, List<Map<String, Object?>>>{};
        for (final table in _tables) {
          final rows = await seedDb.query(table);
          for (final row in rows) {
            final values = Map<String, Object?>.from(row);
            if (version == 1 && table == 'topics') values.remove('pdf_name');
            await old.insert(table, values);
          }
          before[table] = await old.query(table);
        }
        expect(
          (await old.rawQuery('PRAGMA table_info(subjects)'))
              .firstWhere((r) => r['name'] == 'exam')['notnull'],
          1,
        );
        await old.close();
        final store = StudyDatabase(factory: databaseFactoryFfi, path: path);
        addTearDown(store.close);
        final snapshot = await store.readOrMigrate(
          readLegacy: () async => throw StateError('Must not remigrate JSON'),
          normalize: legacy.normalize,
        );
        final db = await store.database;
        for (final table in _tables) {
          final expected = before[table]!;
          expect(
            await db.query(table),
            version == 1 && table == 'topics'
                ? expected.map((r) => {...r, 'pdf_name': 'notes.pdf'}).toList()
                : expected,
            reason: table,
          );
        }
        expect(
          (await db.rawQuery('PRAGMA table_info(subjects)'))
              .firstWhere((r) => r['name'] == 'exam')['notnull'],
          0,
        );
        expect(
          (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
          1,
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        final workspace = const StudyStorage().decode(snapshot);
        workspace.subjects.add(undated('New'));
        await store.write(const StudyStorage().encode(workspace));
        expect(
          (await db.query(
            'subjects',
            where: 'name=?',
            whereArgs: ['New'],
          )).single['exam'],
          isNull,
        );
        final restored = const StudyStorage().decode(
          await store.readOrMigrate(
            readLegacy: () async => null,
            normalize: legacy.normalize,
          ),
        );
        expect(restored.subjects.last.exam, isNull);
        expect(restored.growth.records.single.id, 'stable');
      },
    );
  }
}

const _tables = [
  'workspace_meta',
  'subjects',
  'topics',
  'study_sessions',
  'focus_sessions',
  'focus_spans',
  'study_settings',
];
const _legacySchema = [
  'CREATE TABLE workspace_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  'CREATE TABLE subjects (id TEXT PRIMARY KEY, position INTEGER NOT NULL, name TEXT NOT NULL, exam TEXT NOT NULL, pdf_name TEXT, next_part_id INTEGER NOT NULL)',
  'CREATE TABLE topics (subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE, id INTEGER NOT NULL, position INTEGER NOT NULL, title TEXT NOT NULL, minutes INTEGER NOT NULL, priority INTEGER NOT NULL, completed INTEGER NOT NULL, start_page INTEGER, end_page INTEGER, pdf_name TEXT, PRIMARY KEY(subject_id,id))',
  'CREATE TABLE study_sessions (position INTEGER PRIMARY KEY, subject TEXT NOT NULL, topic TEXT NOT NULL, start TEXT NOT NULL, minutes INTEGER NOT NULL, part_id INTEGER, completed INTEGER NOT NULL, fixed INTEGER NOT NULL)',
  'CREATE TABLE focus_sessions (id TEXT PRIMARY KEY, subject_id TEXT, position INTEGER NOT NULL, planned_ms INTEGER NOT NULL, ended_at TEXT NOT NULL, completed INTEGER NOT NULL, legacy INTEGER NOT NULL, quality TEXT NOT NULL)',
  'CREATE TABLE focus_spans (record_id TEXT NOT NULL REFERENCES focus_sessions(id) ON DELETE CASCADE, position INTEGER NOT NULL, start TEXT NOT NULL, end TEXT NOT NULL, PRIMARY KEY(record_id,position))',
  'CREATE TABLE study_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
];
