import 'interface_test_helpers.dart' as settings;

import 'dart:io';

import 'package:flutter/services.dart';

import 'frontend_completion_test.dart' as previews;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/main.dart';
import 'package:growza/study_ui.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/focus_timer.dart';
import 'package:growza/growth_rules.dart';

class _Store extends StudyStorage {
  late String data;
  @override
  Future<StudyWorkspace> load() async => decode(data);
  @override
  Future<void> save(String value) async {
    data = value;
  }
}

Future<void> reveal(WidgetTester t, Finder f) async {
  t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
  await t.pumpAndSettle();
  await t.scrollUntilVisible(f, 140, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder f) async {
  await reveal(t, f);
  await t.tap(f);
  await t.pumpAndSettle();
}

_Store _store(DateTime now, {List<StudySession>? sessions}) {
  final result = _Store();
  result.data = result.encode(
    StudyWorkspace(
      subjects: [
        StudySubject('Math', now.add(const Duration(days: 5)), [
          const StudyPart(1, 'Algebra', 25),
          const StudyPart(2, 'Calculus', 25),
        ]),
        StudySubject('Physics', now.add(const Duration(days: 4)), [
          const StudyPart(1, 'Waves', 25),
        ]),
      ],
      sessions: sessions,
      recentSubjects: ['Physics'],
    ),
  );
  return result;
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
  testWidgets(
    'Home starts the suggested subject immediately and switching selection takes one tap',
    (t) async {
      final now = DateTime(2026, 11, 14, 10);
      final saved = _store(now);
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: saved, timerNow: () => now),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      expect(find.byType(FocusScreen), findsOneWidget);
      expect(
        t.widget<FocusScreen>(find.byType(FocusScreen)).timer.isRunning,
        isTrue,
      );
      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('ابدأ التركيز'), findsNothing);
      expect(find.byKey(const ValueKey('focus-plant')), findsOneWidget);
      expect(find.byType(Panel), findsNothing);
      await t.tap(find.byTooltip('رجوع'));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('current-subject-Math')));
      final hero = find.byKey(const ValueKey('home-progress-card'));
      await reveal(t, hero);
      expect(
        find.descendant(of: hero, matching: find.text('Math')),
        findsOneWidget,
      );
      expect(find.byType(FocusScreen), findsNothing);
      // Let Flutter report layout exceptions with their widget location.
    },
  );

  testWidgets(
    'Ending a short session saves time and asks once without automatically completing a topic',
    (t) async {
      var now = DateTime(2026, 11, 14, 10);
      final saved = _store(now);
      await t.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture-root'),
          child: GrowzaApp(
            showWelcome: false,
            storage: saved,
            timerNow: () => now,
          ),
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('current-subject-Math')));
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      await previews.capture(t, 'Focus-Stage-2');
      now = now.add(const Duration(minutes: 3, seconds: 30));
      await t.tap(find.text('إنهاء الجلسة'));
      await settings.confirmEnd(t);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('session-review-question')),
        findsOneWidget,
      );
      await previews.capture(t, 'Completion-Stage-2');
      var workspace = saved.decode(saved.data);
      expect(
        workspace.growth.totalFocused,
        const Duration(minutes: 3, seconds: 30),
      );
      expect(
        workspace.growthFor(workspace.subjects.first, now).credited,
        Duration.zero,
      );
      expect(workspace.subjects.first.completedCount, 0);
      expect(workspace.pendingFocusReviewId, isNotNull);
      expect(find.text('حفظ التقدم').hitTestable(), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('review-topic-2')));
      await t.tap(find.text('حفظ التقدم'));
      await t.pumpAndSettle();
      workspace = saved.decode(saved.data);
      expect(workspace.subjects.first.parts[1].completed, isTrue);
      expect(workspace.subjects.first.parts.first.completed, isFalse);
      expect(workspace.pendingFocusReviewId, isNull);
      expect(workspace.focusCount, 0);
    },
  );

  testWidgets(
    'Completed focus offers one review then a break; a new focus starts without another confirmation',
    (t) async {
      var now = DateTime(2026, 11, 14, 10);
      final saved = _store(now);
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: saved, timerNow: () => now),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      final timer = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      now = now.add(const Duration(minutes: 25));
      timer.refresh();
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('session-review-question')),
        findsOneWidget,
      );
      await t.tap(find.text('لم أنهِ موضوعاً'));
      await t.pumpAndSettle();
      expect(find.text('ابدأ الاستراحة'), findsOneWidget);
      expect(saved.decode(saved.data).subjects[1].completedCount, 0);
      await t.tap(find.byTooltip('رجوع'));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      expect(find.text('تغيير الجلسة؟'), findsNothing);
      final next = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      expect(next.phase, TimerPhase.focus);
      expect(next.isRunning, isTrue);
      expect(saved.decode(saved.data).growth.records, hasLength(1));
    },
  );

  testWidgets(
    'Unanswered session review survives reload without duplicate focus credit',
    (t) async {
      var now = DateTime(2026, 11, 14, 10);
      final saved = _store(now);
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: saved, timerNow: () => now),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      final timer = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      now = now.add(const Duration(minutes: 25));
      timer.refresh();
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('session-review-question')),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: saved, timerNow: () => now),
      );
      await t.pumpAndSettle();
      await tap(t, find.text('مراجعة الجلسة'));
      await tap(t, find.byKey(const ValueKey('review-topic-1')));
      await t.tap(find.text('حفظ التقدم'));
      await t.pumpAndSettle();
      final workspace = saved.decode(saved.data);
      expect(workspace.growth.records, hasLength(1));
      expect(workspace.focusCount, 1);
      expect(workspace.subjects[1].parts.single.completed, isTrue);
      expect(workspace.pendingFocusReviewId, isNull);
    },
  );

  testWidgets(
    'The daily cap message appears while time continues to be recorded',
    (t) async {
      var now = DateTime(2026, 11, 14, 10);
      final saved = _store(
        now,
        sessions: [
          StudySession(
            'Math',
            'Previous focus',
            DateTime(2026, 11, 14, 5),
            235,
            completed: true,
          ),
        ],
      );
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: saved, timerNow: () => now),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      final timer = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      now = now.add(const Duration(minutes: 6));
      timer.refresh();
      await t.pumpAndSettle();
      expect(find.text(GrowthRules.dailyLimitMessage), findsOneWidget);
      await t.tap(find.text('إنهاء الجلسة'));
      await settings.confirmEnd(t);
      await t.pumpAndSettle();
      final workspace = saved.decode(saved.data);
      expect(workspace.growth.totalFocused, const Duration(minutes: 241));
      expect(
        workspace.growth.forDay(now).credited,
        const Duration(minutes: 240),
      );
      expect(workspace.subjects[1].completedCount, 0);
    },
  );

  testWidgets(
    'Long names and the completion actions fit narrow screens with large text',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 700));
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        t.platformDispatcher.clearTextScaleFactorTestValue();
        return t.binding.setSurfaceSize(null);
      });
      var now = DateTime(2026, 11, 14, 10);
      final saved = _Store();
      saved.data = saved.encode(
        StudyWorkspace(
          subjects: [
            StudySubject(
              'الرياضيات المتقدمة وتطبيقاتها في العلوم والهندسة',
              now.add(const Duration(days: 5)),
              [
                for (var i = 1; i <= 20; i++)
                  StudyPart(i, 'موضوع طويل للمراجعة والتدريب رقم $i', 25),
              ],
            ),
          ],
        ),
      );
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: saved, timerNow: () => now),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      // Let Flutter report layout exceptions with their widget location.
      now = now.add(const Duration(minutes: 6));
      await t.tap(find.text('إنهاء الجلسة'));
      await settings.confirmEnd(t);
      await t.pumpAndSettle();
      expect(find.text('حفظ التقدم').hitTestable(), findsOneWidget);
      expect(find.text('لم أنهِ موضوعاً').hitTestable(), findsOneWidget);
      // Let Flutter report layout exceptions with their widget location.
    },
  );
}
