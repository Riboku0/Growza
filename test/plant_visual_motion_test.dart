import 'interface_test_helpers.dart' as settings;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/app_theme.dart';
import 'package:growza/app_header.dart';
import 'package:growza/main.dart';
import 'package:growza/motion.dart';
import 'package:growza/forest_scene.dart';
import 'package:growza/plant_visual.dart';
import 'package:growza/growth_rules.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';

import 'frontend_completion_test.dart' as previews;
import 'study_flow_stage2_test.dart' as flow;

class _Store extends StudyStorage {
  late String data;
  @override
  Future<StudyWorkspace> load() async => decode(data);
  @override
  Future<void> save(String value) async {
    data = value;
  }
}

_Store _fixture() {
  final s = _Store();
  s.data = s.encode(
    StudyWorkspace(
      subjects: [
        StudySubject('الأحياء', DateTime(2026, 11, 20), [
          for (var i = 1; i <= 8; i++)
            StudyPart(i, 'الفصل $i', 25, completed: i <= 3),
        ]),
        StudySubject('الرياضيات', DateTime(2026, 11, 23), [
          const StudyPart(1, 'التكامل', 25),
        ]),
        StudySubject('الفيزياء', DateTime(2026, 11, 24), [
          const StudyPart(1, 'الموجات', 25),
        ]),
      ],
      sessions: [
        for (var day = 7; day <= 12; day++)
          StudySession(
            'الأحياء',
            'تركيز سابق',
            DateTime(2026, 11, day, 8),
            200,
            completed: true,
          ),
      ],
      recentSubjects: ['الأحياء'],
    ),
  );
  return s;
}

Widget _plantApp({bool enabled = true}) => MaterialApp(
  theme: buildGrowzaTheme(),
  home: Scaffold(
    body: TickerMode(
      enabled: enabled,
      child: Center(
        child: SizedBox(
          width: 280,
          height: 280,
          child: ForestScene(
            child: PlantView(
              stage: PlantStage.tree,
              flowerCount: 3,
              state: PlantVisualState.breathing,
            ),
          ),
        ),
      ),
    ),
  ),
);
void _enableMotion(WidgetTester t) =>
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
void main() {
  testWidgets(
    'All five plant stages and thumbnails render through one painter',
    (t) async {
      for (final stage in PlantStage.values) {
        await t.pumpWidget(
          MaterialApp(
            theme: buildGrowzaTheme(),
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: PlantView(
                        stage: stage,
                        progress: .25,
                        flowerCount: 3,
                        animate: false,
                      ),
                    ),
                    PlantThumbnail(stage: stage, flowerCount: 1),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(PlantView), findsNWidgets(2));
        expect(t.takeException(), isNull);
      }
    },
  );
  testWidgets('Reduced motion leaves breathing plants and butterfly static', (
    t,
  ) async {
    await t.pumpWidget(_plantApp());
    await t.pumpAndSettle();
    for (final state in t.stateList<MotionLoopState>(find.byType(MotionLoop))) {
      expect(state.isAnimating, isFalse);
    }
    expect(t.binding.transientCallbackCount, 0);
  });
  testWidgets(
    'Motion suspends for hidden routes and resumes without controller leaks',
    (t) async {
      _enableMotion(t);
      await t.pumpWidget(_plantApp());
      await t.pump(const Duration(milliseconds: 100));
      expect(
        t
            .stateList<MotionLoopState>(find.byType(MotionLoop))
            .every((s) => s.isAnimating),
        isTrue,
      );
      await t.pumpWidget(_plantApp(enabled: false));
      await t.pump(const Duration(milliseconds: 100));
      expect(
        t
            .stateList<MotionLoopState>(find.byType(MotionLoop))
            .every((s) => !s.isAnimating),
        isTrue,
      );
      await t.pumpWidget(_plantApp());
      await t.pump(const Duration(milliseconds: 100));
      expect(
        t
            .stateList<MotionLoopState>(find.byType(MotionLoop))
            .every((s) => s.isAnimating),
        isTrue,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Decorative motion stops in the background and restarts on resume',
    (t) async {
      _enableMotion(t);
      await t.pumpWidget(_plantApp());
      await t.pump(const Duration(milliseconds: 100));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(
        t
            .stateList<MotionLoopState>(find.byType(MotionLoop))
            .every((s) => !s.isAnimating),
        isTrue,
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(milliseconds: 100));
      expect(
        t
            .stateList<MotionLoopState>(find.byType(MotionLoop))
            .every((s) => s.isAnimating),
        isTrue,
      );
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Offscreen plants stop continuous motion in a scroll viewport', (
    t,
  ) async {
    _enableMotion(t);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(
                  height: 260,
                  child: PlantView(
                    stage: PlantStage.plant,
                    state: PlantVisualState.breathing,
                  ),
                ),
                const SizedBox(height: 1500),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    final state = t.state<MotionLoopState>(find.byType(MotionLoop));
    expect(state.isAnimating, isTrue);
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -900));
    await t.pump(const Duration(seconds: 1));
    expect(state.isAnimating, isFalse);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Home, Study and Schedule share the same header position', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(392, 850));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final saved = _fixture();
    await t.pumpWidget(
      GrowzaApp(
        showWelcome: false,
        storage: saved,
        timerNow: () => DateTime(2026, 11, 14, 10),
      ),
    );
    await t.pumpAndSettle();
    final initial = t.getRect(find.byType(AppHeader));
    for (final label in ['المواد', 'الجدول', 'الرئيسية']) {
      await t.tap(find.text(label));
      await t.pumpAndSettle();
      expect(find.byType(AppHeader), findsOneWidget);
      final rect = t.getRect(find.byType(AppHeader));
      expect(rect.topLeft, initial.topLeft);
      expect(rect.size, initial.size);
    }
  });
  testWidgets('The same topic completion count appears on Home and Study', (
    t,
  ) async {
    final saved = _Store();
    saved.data = saved.encode(
      StudyWorkspace(
        subjects: [
          StudySubject('IoT', DateTime(2026, 11, 20), [
            const StudyPart(1, 'Networks', 25, completed: true),
          ]),
        ],
      ),
    );
    await t.pumpWidget(
      GrowzaApp(
        showWelcome: false,
        storage: saved,
        timerNow: () => DateTime(2026, 11, 14, 10),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('1 من 1'), findsOneWidget);
    expect(
      find.text('أنهيت مواضيعك، بقي أن تذاكر لتنمو نبتتك.'),
      findsOneWidget,
    );
    await t.tap(find.text('المواد'));
    await t.pumpAndSettle();
    expect(find.textContaining('المواضيع: 1 من 1'), findsOneWidget);
    expect(saved.decode(saved.data).growth.totalFocused, Duration.zero);
    expect(saved.decode(saved.data).subjects.single.completedCount, 1);
  });
  testWidgets('An empty subject is not presented as completed', (t) async {
    final saved = _Store();
    saved.data = saved.encode(
      StudyWorkspace(
        subjects: [StudySubject('Security', DateTime(2026, 11, 20), [])],
      ),
    );
    await t.pumpWidget(
      GrowzaApp(
        showWelcome: false,
        storage: saved,
        timerNow: () => DateTime(2026, 11, 14, 10),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('لا توجد مواضيع بعد'), findsOneWidget);
    await t.tap(find.text('المواد'));
    await t.pumpAndSettle();
    expect(find.textContaining('لا توجد مواضيع بعد'), findsOneWidget);
    expect(find.text('مكتمل'), findsNothing);
  });
  testWidgets('Approved flat forest, stage gallery and night scene previews', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(392, 850));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final saved = _fixture();
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture-root'),
        child: GrowzaApp(
          showWelcome: false,
          storage: saved,
          timerNow: () => DateTime(2026, 11, 14, 10),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/growza-icon.png'),
        t.element(find.byType(Scaffold).first),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(ForestScene), findsOneWidget);
    await previews.capture(t, 'Visual-After-Home');
    await t.tap(find.byTooltip('مراحل النمو'));
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(PlantThumbnail),
      ),
      findsNWidgets(5),
    );
    await previews.capture(t, 'Visual-After-Stages');
    await flow.tap(t, find.text('العودة للحديقة'));
    await settings.chooseAppearance(t, 'dark');
    await t.pumpAndSettle();
    await previews.capture(t, 'Visual-After-Night');
    await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
    await previews.capture(t, 'Visual-After-Focus');
    expect(t.takeException(), isNull);
  });
}
