import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/exam_countdown.dart';
import 'package:growza/main.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_garden.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/plant_visual.dart';
import 'package:growza/growth_rules.dart';

import 'study_flow_stage2_test.dart' as flow;
import 'frontend_completion_test.dart' as previews;

class _Store extends StudyStorage {
  late String data;
  @override
  Future<StudyWorkspace> load() async => decode(data);
  @override
  Future<void> save(String value) async {
    data = value;
  }
}

_Store _fixture(DateTime now) {
  final saved = _Store();
  saved.data = saved.encode(
    StudyWorkspace(
      subjects: [
        StudySubject('Math', now.add(const Duration(days: 5)), [
          const StudyPart(1, 'Algebra', 25),
        ]),
        StudySubject('Physics', now.add(const Duration(days: 7)), [
          const StudyPart(1, 'Waves', 25, completed: true),
        ]),
        StudySubject('Chemistry', DateTime(2026, 11, 13), [
          const StudyPart(1, 'Atoms', 25),
        ]),
      ],
      sessions: [
        StudySession(
          'Math',
          'Previous focus',
          DateTime(2026, 11, 14, 7),
          90,
          completed: true,
        ),
        for (var day = 10; day <= 12; day++)
          StudySession(
            'Chemistry',
            'Previous focus',
            DateTime(2026, 11, day, 7),
            200,
            completed: true,
          ),
      ],
      recentSubjects: ['Math'],
    ),
  );
  return saved;
}

Future<void> _open(
  WidgetTester t,
  _Store saved,
  DateTime Function() now,
) async {
  await t.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture-root'),
      child: GrowzaApp(showWelcome: false, storage: saved, timerNow: now),
    ),
  );
  await t.pumpAndSettle();
  if (Platform.environment['GROWZA_CAPTURE_FRONTEND'] == '1') {
    await t.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/study-forest-v1.png'),
        t.element(find.byType(Scaffold).first),
      ),
    );
    await t.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    if (Platform.environment['GROWZA_CAPTURE_FRONTEND'] != '1') return;
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final name
          in family == 'Roboto'
              ? ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']
              : ['materialicons-regular.otf']) {
        loader.addFont(
          Future.value(
            ByteData.sublistView(
              File('C:/src/flutter/bin/cache/artifacts/material_fonts/$name')
                  .readAsBytesSync(),
            ),
          ),
        );
      }
      await loader.load();
    }
  });
  test(
    'Exam countdown uses calendar dates and the correct timed/all-day cutoff',
    () {
      final today = DateTime(2026, 11, 14, 23, 59);
      expect(
        examCountdownLabel(DateTime(2026, 11, 19), today),
        'الأيام المتبقية: 5',
      );
      expect(
        examCountdownLabel(DateTime(2026, 11, 15, 8), today),
        'الاختبار غداً',
      );
      expect(
        examCountdownLabel(DateTime(2026, 11, 14), today),
        'الاختبار اليوم',
      );
      expect(
        examCountdownLabel(DateTime(2026, 11, 14), DateTime(2026, 11, 15)),
        'مضى الاختبار',
      );
      expect(
        examCountdownLabel(
          DateTime(2026, 11, 14, 12),
          DateTime(2026, 11, 14, 11, 59),
        ),
        'الاختبار اليوم',
      );
      expect(
        examCountdownLabel(
          DateTime(2026, 11, 14, 12),
          DateTime(2026, 11, 14, 12),
        ),
        'مضى الاختبار',
      );
      expect(
        examCountdownLabel(DateTime(2027, 1, 1), DateTime(2026, 12, 31, 23)),
        'الاختبار غداً',
      );
    },
  );
  testWidgets(
    'Garden renders migrated focus independently of topic flowers and keeps current subjects flat',
    (t) async {
      final now = DateTime(2026, 11, 14, 10);
      final saved = _fixture(now);
      await t.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await _open(t, saved, () => now);
      expect(find.text('الأيام المتبقية: 5'), findsOneWidget);
      await previews.capture(t, 'Home-Stage-3');
      await flow.reveal(t, find.byType(StudyGarden));
      final garden = t.widget<StudyGarden>(find.byType(StudyGarden));
      final math = garden.progress.firstWhere((p) => p.subject == 'Math');
      final physics = garden.progress.firstWhere((p) => p.subject == 'Physics');
      expect(math.growth.stage, PlantStage.plant);
      expect(math.growth.credited, const Duration(minutes: 90));
      expect(math.growth.topicProgress, 0);
      expect(physics.growth.stage, PlantStage.seed);
      expect(physics.growth.topicProgress, 1);
      final flower = t.widget<PlantView>(
        find.descendant(
          of: find.byKey(const ValueKey('current-subject-Physics')),
          matching: find.byType(PlantView),
        ),
      );
      expect(flower.stage, PlantStage.seed);
      expect(flower.flowerCount, 1);
      expect(
        find.byKey(ValueKey('garden-plant-${garden.progress.last.id}')),
        findsNothing,
      );
      expect(saved.decode(saved.data).subjects, hasLength(3));
      await previews.capture(t, 'Garden-Stage-3');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Achievements expand in place without completing topics or deleting subject history',
    (t) async {
      final now = DateTime(2026, 11, 14, 10);
      final saved = _fixture(now);
      final before = saved.decode(saved.data);
      await _open(t, saved, () => now);
      await flow.tap(t, find.byKey(const ValueKey('garden-achievements')));
      expect(
        find.byKey(ValueKey('harvested-${before.subjects.last.id}')),
        findsOneWidget,
      );
      expect(find.textContaining('شجرة · التركيز: 600 د'), findsOneWidget);
      expect(find.textContaining('المواضيع المنجزة: 0 / 1'), findsOneWidget);
      final after = saved.decode(saved.data);
      expect(after.subjects.map((s) => s.id), before.subjects.map((s) => s.id));
      expect(after.subjects.last.parts.single.completed, isFalse);
      expect(after.growth.records.length, before.growth.records.length);
      expect(after.sessions.length, before.sessions.length);
      await previews.capture(t, 'Achievements-Stage-3');
      expect(find.byType(MaterialApp), findsOneWidget);
    },
  );
  testWidgets(
    'An exam passing while Home is open harvests the plant; a later exam restores it without losing growth',
    (t) async {
      var now = DateTime(2026, 11, 14, 11, 59);
      final saved = _Store();
      saved.data = saved.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('Math', DateTime(2026, 11, 14, 12), [
              const StudyPart(1, 'Algebra', 25),
            ]),
          ],
          sessions: [
            StudySession(
              'Math',
              'Previous focus',
              DateTime(2026, 11, 14, 7),
              60,
              completed: true,
            ),
          ],
        ),
      );
      await _open(t, saved, () => now);
      expect(find.text('الاختبار اليوم'), findsOneWidget);
      now = DateTime(2026, 11, 14, 12);
      await t.pump(const Duration(minutes: 1));
      await t.pumpAndSettle();
      await flow.tap(t, find.byKey(const ValueKey('garden-achievements')));
      expect(find.textContaining('نبتة · التركيز: 60 د'), findsOneWidget);
      final current = saved.decode(saved.data);
      final subject = current.subjects.single;
      current.subjects[0] = StudySubject(
        subject.name,
        DateTime(2026, 11, 20),
        subject.parts,
        id: subject.id,
      );
      saved.data = saved.encode(current);
      await t.pumpWidget(const SizedBox.shrink());
      await _open(t, saved, () => now);
      expect(find.text('الأيام المتبقية: 6'), findsOneWidget);
      await flow.reveal(t, find.byType(StudyGarden));
      expect(find.byKey(const ValueKey('garden-achievements')), findsNothing);
      expect(
        find.byKey(ValueKey('home-focused-plant-${subject.id}')),
        findsOneWidget,
      );
      expect(
        saved.decode(saved.data).growth.totalFocused,
        const Duration(minutes: 60),
      );
    },
  );
  testWidgets(
    'An all-harvested garden offers the next subject without pretending this is a new user',
    (t) async {
      final now = DateTime(2026, 11, 14, 10);
      final saved = _Store();
      saved.data = saved.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('Previous course', DateTime(2026, 11, 13), [
              const StudyPart(1, 'الموضوع', 25),
            ]),
          ],
        ),
      );
      await _open(t, saved, () => now);
      expect(find.text('أضف مادتك الأولى'), findsNothing);
      expect(find.byKey(const ValueKey('home-start-study')), findsNothing);
      await flow.tap(t, find.byKey(const ValueKey('garden-achievements')));
      expect(find.text('Previous course'), findsOneWidget);
      expect(
        saved.decode(saved.data).subjects.single.parts.single.completed,
        isFalse,
      );
    },
  );
  testWidgets(
    'Garden and stage preview fit long Arabic names and enlarged text',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 700));
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        t.platformDispatcher.clearTextScaleFactorTestValue();
        return t.binding.setSurfaceSize(null);
      });
      final now = DateTime(2026, 11, 14, 10);
      final saved = _fixture(now);
      final workspace = saved.decode(saved.data);
      final subject = workspace.subjects.first;
      workspace.subjects[0] = StudySubject(
        'الرياضيات المتقدمة وتطبيقاتها في العلوم والهندسة',
        subject.exam,
        subject.parts,
        id: subject.id,
      );
      saved.data = saved.encode(workspace);
      await _open(t, saved, () => now);
      await flow.tap(t, find.byTooltip('مراحل النمو'));
      expect(find.text('شجرة · 300 دقيقة'), findsOneWidget);
      await t.ensureVisible(find.text('برعم 15 دقيقة'));
      await t.pumpAndSettle();
      await t.tap(find.text('برعم 15 دقيقة'));
      await t.pumpAndSettle();
      expect(find.text('برعم · 15 دقيقة'), findsOneWidget);
      await flow.tap(t, find.text('العودة للحديقة'));
      await flow.tap(t, find.byKey(const ValueKey('garden-achievements')));
      expect(t.takeException(), isNull);
    },
  );
}
