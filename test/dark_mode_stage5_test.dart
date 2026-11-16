import 'interface_test_helpers.dart' as settings;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/app_theme.dart';
import 'package:growza/main.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/focus_screen.dart';
import 'package:growza/study_garden.dart';
import 'package:growza/plant_visual.dart';

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

_Store _fixture(DateTime now, {bool? dark}) {
  final s = _Store();
  s.data = s.encode(
    StudyWorkspace(
      darkMode: dark,
      subjects: [
        StudySubject('الرياضيات', DateTime(2026, 11, 20), [
          const StudyPart(1, 'التكامل', 25),
          const StudyPart(2, 'التفاضل', 25, completed: true),
        ]),
      ],
      sessions: [
        StudySession(
          'الرياضيات',
          'جلسة سابقة',
          DateTime(2026, 11, 13, 8),
          90,
          completed: true,
        ),
      ],
    ),
  );
  return s;
}

Brightness _brightness(WidgetTester t) =>
    Theme.of(t.element(find.byType(Scaffold).last)).brightness;
Future<void> _open(WidgetTester t, _Store s, DateTime Function() now) async {
  await t.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture-root'),
      child: GrowzaApp(showWelcome: false, storage: s, timerNow: now),
    ),
  );
  await t.pumpAndSettle();
  await t.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/study-forest-v1.png'),
      t.element(find.byType(Scaffold).first),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('Old workspaces default to system and appearance round-trips without touching study data', () {
    final now = DateTime(2026, 11, 14, 10);
    final s = _fixture(now);
    final map = jsonDecode(s.data) as Map<String, dynamic>;
    map.remove('darkMode');
    final restored = s.decode(jsonEncode(map));
    expect(restored.darkMode, isNull);
    final original = jsonEncode(
      restored.subjects.map((v) => v.toJson()).toList(),
    );
    restored.darkMode = true;
    final dark = s.decode(s.encode(restored));
    expect(dark.darkMode, isTrue);
    expect(jsonEncode(dark.subjects.map((v) => v.toJson()).toList()), original);
    expect(dark.growth.totalFocused, const Duration(minutes: 90));
    dark.darkMode = false;
    expect(s.decode(s.encode(dark)).darkMode, isFalse);
  });
  test(
    'Night palette has readable text, secondary text and primary actions',
    () {
      double ratio(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      final p = GrowzaPalette.dark;
      expect(ratio(p.foreground, p.background), greaterThanOrEqualTo(4.5));
      expect(ratio(p.secondaryText, p.card), greaterThanOrEqualTo(4.5));
      final theme = buildGrowzaTheme(brightness: Brightness.dark);
      expect(
        ratio(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        growzaSystemBarsFor(Brightness.dark).statusBarIconBrightness,
        Brightness.light,
      );
    },
  );
  testWidgets(
    'Night toggle persists after reload and retains subjects, topics and focus history',
    (t) async {
      final now = DateTime(2026, 11, 14, 10);
      final s = _fixture(now);
      final before = s.decode(s.data);
      await _open(t, s, () => now);
      expect(_brightness(t), Brightness.light);
      await settings.chooseAppearance(t, 'dark');
      await t.pumpAndSettle();
      expect(_brightness(t), Brightness.dark);
      expect(s.decode(s.data).darkMode, isTrue);
      expect(
        Theme.of(t.element(find.byType(Scaffold).first))
            .scaffoldBackgroundColor,
        GrowzaPalette.dark.background,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await _open(t, s, () => now);
      expect(_brightness(t), Brightness.dark);
      final after = s.decode(s.data);
      expect(after.subjects.single.id, before.subjects.single.id);
      expect(
        after.subjects.single.parts.map((p) => p.completed),
        before.subjects.single.parts.map((p) => p.completed),
      );
      expect(after.growth.totalFocused, before.growth.totalFocused);
      await settings.chooseAppearance(t, 'light');
      await t.pumpAndSettle();
      expect(_brightness(t), Brightness.light);
      expect(s.decode(s.data).darkMode, isFalse);
    },
  );
  testWidgets(
    'System appearance updates until the user makes an explicit choice',
    (t) async {
      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      final now = DateTime(2026, 11, 14, 10);
      final s = _fixture(now);
      await _open(t, s, () => now);
      expect(_brightness(t), Brightness.dark);
      expect(s.decode(s.data).darkMode, isNull);
      t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await t.pumpAndSettle();
      expect(_brightness(t), Brightness.light);
      await settings.chooseAppearance(t, 'dark');
      await t.pumpAndSettle();
      expect(_brightness(t), Brightness.dark);
      t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await t.pumpAndSettle();
      expect(_brightness(t), Brightness.dark);
    },
  );
  testWidgets(
    'Night focus, completion, flowers and garden retain the same study flow',
    (t) async {
      await t.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => t.binding.setSurfaceSize(null));
      var now = DateTime(2026, 11, 14, 10);
      final s = _fixture(now, dark: true);
      await _open(t, s, () => now);
      await previews.capture(t, 'Night-Home-Stage-5');
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      expect(_brightness(t), Brightness.dark);
      expect(
        t.widget<FocusScreen>(find.byType(FocusScreen)).timer.isRunning,
        isTrue,
      );
      final plant = find.descendant(
        of: find.byKey(const ValueKey('focus-plant')),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is StudyPlantPainter,
        ),
      );
      expect(
        (t.widget<CustomPaint>(plant).painter! as StudyPlantPainter).dark,
        isTrue,
      );
      await previews.capture(t, 'Night-Focus-Stage-5');
      now = now.add(const Duration(minutes: 6));
      await t.tap(find.text('إنهاء الجلسة'));
      await settings.confirmEnd(t);
      await t.pumpAndSettle();
      expect(_brightness(t), Brightness.dark);
      expect(find.text('هل أنهيت موضوعاً؟'), findsOneWidget);
      await previews.capture(t, 'Night-Completion-Stage-5');
      await flow.tap(t, find.byKey(const ValueKey('review-topic-1')));
      await t.tap(find.text('حفظ التقدم'));
      await t.pumpAndSettle();
      await flow.reveal(t, find.byType(StudyGarden));
      expect(s.decode(s.data).subjects.single.completedCount, 2);
      expect(s.decode(s.data).growth.totalFocused, const Duration(minutes: 96));
      await previews.capture(t, 'Night-Garden-Stage-5');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Changing appearance during focus preserves the timer and does not settle it',
    (t) async {
      var now = DateTime(2026, 11, 14, 10);
      final saved = _fixture(now);
      await _open(t, saved, () => now);
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      final timer = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      final id = timer.recordId;
      now = now.add(const Duration(minutes: 2));
      timer.refresh();
      await t.tap(find.byTooltip('رجوع'));
      await t.pumpAndSettle();
      await settings.chooseAppearance(t, 'dark');
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      final resumed = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      expect(identical(resumed, timer), isTrue);
      expect(resumed.recordId, id);
      expect(resumed.remaining, const Duration(minutes: 23));
      expect(resumed.isRunning, isTrue);
      expect(saved.decode(saved.data).growth.records, hasLength(1));
      expect(_brightness(t), Brightness.dark);
    },
  );
  testWidgets(
    'Night forms, date dialogs and schedule fit narrow Arabic layouts',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 700));
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        t.platformDispatcher.clearTextScaleFactorTestValue();
        return t.binding.setSurfaceSize(null);
      });
      final now = DateTime(2026, 11, 14, 10);
      final s = _fixture(now, dark: true);
      await _open(t, s, () => now);
      await t.tap(find.text('المواد'));
      await t.pumpAndSettle();
      await flow.tap(t, find.text('أضف مادة'));
      expect(_brightness(t), Brightness.dark);
      await flow.tap(t, find.text('اختر موعد الاختبار'));
      final ctx = t.element(find.byType(DatePickerDialog));
      expect(Theme.of(ctx).brightness, Brightness.dark);
      expect(Directionality.of(ctx), TextDirection.rtl);
      await t.tap(find.text(MaterialLocalizations.of(ctx).cancelButtonLabel));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('رجوع'));
      await t.pumpAndSettle();
      await t.tap(find.text('الجدول'));
      await t.pumpAndSettle();
      expect(_brightness(t), Brightness.dark);
      expect(t.takeException(), isNull);
    },
  );
}
