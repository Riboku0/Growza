import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/main.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/growth_rules.dart';
import 'package:growza/focus_screen.dart';

import 'frontend_completion_test.dart' as previews;
import 'study_flow_stage2_test.dart' as flow;
import 'interface_test_helpers.dart' as dialogs;

class MemoryStore extends StudyStorage {
  late String data;
  @override
  Future<StudyWorkspace> load() async => decode(data);
  @override
  Future<void> save(String snapshot) async {
    data = snapshot;
  }
}

MemoryStore fixture({String language = 'ar', bool empty = false}) {
  final result = MemoryStore();
  result.data = result.encode(
    StudyWorkspace(
      languageCode: language,
      subjects: [
        StudySubject(
          'Calculus II',
          DateTime(2026, 12, 1),
          empty
              ? []
              : [
                  const StudyPart(1, 'Integration', 45),
                  const StudyPart(2, 'Series', 60),
                  const StudyPart(3, 'Applications', 75),
                  const StudyPart(4, 'Practice', 120),
                ],
        ),
      ],
    ),
  );
  return result;
}

Future<void> open(
  WidgetTester t,
  MemoryStore s,
  DateTime Function() now,
) async {
  await t.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture-root'),
      child: GrowzaApp(showWelcome: false, storage: s, timerNow: now),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> end(WidgetTester t) async {
  await t.tap(find.text('إنهاء الجلسة'));
  await dialogs.confirmEnd(t);
}

void main() {
  testWidgets(
    'Half focus changes growth preview and persists with topics, not actual statistics or IDs',
    (t) async {
      var now = DateTime(2026, 11, 15, 10);
      final s = fixture();
      await open(t, s, () => now);
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      now = now.add(const Duration(minutes: 10));
      await end(t);
      expect(
        find.byKey(const ValueKey('session-quality-question')),
        findsOneWidget,
      );
      final original = s.decode(s.data).growth.records.single;
      expect(original.quality, FocusQuality.full);
      await flow.tap(t, find.byKey(const ValueKey('quality-half')));
      await flow.reveal(t, find.byKey(const ValueKey('session-growth-result')));
      expect(find.text('نمت نبتتك 6 دقيقة.'), findsOneWidget);
      expect(
        s.decode(s.data).growth.records.single.quality,
        FocusQuality.full,
        reason: 'Preview must not commit until confirmation',
      );
      await flow.tap(t, find.byKey(const ValueKey('review-topic-1')));
      await t.tap(find.text('حفظ التقدم'));
      await t.pumpAndSettle();
      final after = s.decode(s.data);
      expect(after.growth.records.single.id, original.id);
      expect(after.growth.records.single.quality, FocusQuality.half);
      expect(after.growth.totalFocused, const Duration(minutes: 10));
      expect(
        after.growthFor(after.subjects.single, now).credited,
        const Duration(minutes: 6),
      );
      expect(after.growth.forDay(now).budgetUsed, const Duration(minutes: 10));
      expect(after.subjects.single.completedCount, 1);
      expect(after.pendingFocusReviewId, isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await open(t, s, () => now);
      expect(s.decode(s.data).growth.records, hasLength(1));
      expect(s.decode(s.data).growth.records.single.quality, FocusQuality.half);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Skipping quality explicitly restores Full and leaving topics open preserves time',
    (t) async {
      var now = DateTime(2026, 11, 15, 10);
      final s = fixture();
      await open(t, s, () => now);
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      now = now.add(const Duration(minutes: 10));
      await end(t);
      await flow.tap(t, find.byKey(const ValueKey('quality-distracted')));
      await flow.reveal(t, find.byKey(const ValueKey('session-growth-result')));
      expect(find.text('نمت نبتتك 2.5 دقيقة.'), findsOneWidget);
      await flow.tap(t, find.byKey(const ValueKey('quality-skip')));
      await flow.reveal(t, find.byKey(const ValueKey('session-growth-result')));
      expect(find.text('نمت نبتتك 10 دقيقة.'), findsOneWidget);
      await t.tap(find.text('لم أنهِ موضوعاً'));
      await t.pumpAndSettle();
      final after = s.decode(s.data);
      expect(after.growth.records.single.quality, FocusQuality.full);
      expect(
        after.growthFor(after.subjects.single, now).credited,
        const Duration(minutes: 10),
      );
      expect(after.subjects.single.completedCount, 0);
      expect(after.growth.totalFocused, const Duration(minutes: 10));
    },
  );
  testWidgets(
    'Unconfirmed quality is not persisted; pending review reload is settled once with Distracted',
    (t) async {
      var now = DateTime(2026, 11, 15, 10);
      final s = fixture();
      await open(t, s, () => now);
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      now = now.add(const Duration(minutes: 6));
      await end(t);
      final id = s.decode(s.data).growth.records.single.id;
      await flow.tap(t, find.byKey(const ValueKey('quality-half')));
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(s.decode(s.data).pendingFocusReviewId, id);
      expect(s.decode(s.data).growth.records.single.quality, FocusQuality.full);
      await t.pumpWidget(const SizedBox.shrink());
      await open(t, s, () => now);
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      await flow.tap(t, find.byKey(const ValueKey('quality-distracted')));
      await t.tap(find.text('لم أنهِ موضوعاً'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox.shrink());
      await open(t, s, () => now);
      final after = s.decode(s.data);
      expect(after.pendingFocusReviewId, isNull);
      expect(after.growth.records, hasLength(1));
      expect(after.growth.records.single.id, id);
      expect(after.growth.records.single.quality, FocusQuality.distracted);
      expect(
        after.growthFor(after.subjects.single, now).credited,
        const Duration(minutes: 1, seconds: 30),
      );
      expect(after.growth.totalFocused, const Duration(minutes: 6));
    },
  );
  testWidgets(
    'Short sessions never grow with a quality choice; topic flowers remain independent',
    (t) async {
      var now = DateTime(2026, 11, 15, 10);
      final s = fixture();
      await open(t, s, () => now);
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      now = now.add(const Duration(minutes: 3));
      await end(t);
      await flow.tap(t, find.byKey(const ValueKey('quality-distracted')));
      await flow.reveal(t, find.byKey(const ValueKey('session-growth-result')));
      expect(find.textContaining('الجلسات الأقل من 5 دقائق'), findsOneWidget);
      await flow.tap(t, find.byKey(const ValueKey('review-topic-1')));
      await t.tap(find.text('حفظ التقدم'));
      await t.pumpAndSettle();
      final after = s.decode(s.data);
      expect(after.growth.totalFocused, const Duration(minutes: 3));
      expect(
        after.growthFor(after.subjects.single, now).credited,
        Duration.zero,
      );
      expect(after.subjects.single.completedCount, 1);
    },
  );
  testWidgets(
    'Calculus II Home opens its 600-minute stages instead of the legacy thresholds',
    (t) async {
      await t.binding.setSurfaceSize(const Size(392, 850));
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(392, 850);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        return t.binding.setSurfaceSize(null);
      });
      final now = DateTime(2026, 11, 15, 10);
      final s = fixture();
      await open(t, s, () => now);
      await flow.tap(t, find.byTooltip('مراحل النمو'));
      expect(find.text('شجرة · 600 دقيقة'), findsOneWidget);
      expect(find.text('برعم 30 دقيقة'), findsOneWidget);
      expect(find.text('نبتة 120 دقيقة'), findsOneWidget);
      expect(find.text('شجيرة 300 دقيقة'), findsOneWidget);
      expect(find.textContaining('هدف المادة: 600 دقيقة'), findsOneWidget);
      await previews.capture(t, 'Calculus-II-Stage-Preview');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('No-topic subject explains its unchanged 1200-minute fallback', (
    t,
  ) async {
    final now = DateTime(2026, 11, 15, 10);
    final s = fixture(empty: true);
    await open(t, s, () => now);
    await flow.tap(t, find.byTooltip('مراحل النمو'));
    expect(find.textContaining('يبقى هدف النمو 1200 دقيقة'), findsOneWidget);
    expect(find.text('شجرة · 1200 دقيقة'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Bilingual quality controls and save actions fit enlarged narrow screens',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 700));
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 700);
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        t.platformDispatcher.clearTextScaleFactorTestValue();
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        return t.binding.setSurfaceSize(null);
      });
      for (final language in ['ar', 'en']) {
        var now = DateTime(2026, 11, 15, 10);
        final s = fixture(language: language);
        await open(t, s, () => now);
        await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
        final timer = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
        now = now.add(const Duration(minutes: 6));
        timer.refresh();
        await t.tap(
          find.text(language == 'ar' ? 'إنهاء الجلسة' : 'End session'),
        );
        await t.pumpAndSettle();
        await t.tap(
          find.widgetWithText(
            FilledButton,
            language == 'ar' ? 'إنهاء الجلسة' : 'End session',
          ),
        );
        await t.pumpAndSettle();
        await flow.tap(t, find.byKey(const ValueKey('quality-half')));
        await flow.tap(t, find.byKey(const ValueKey('review-topic-1')));
        await t.tap(
          find.text(language == 'ar' ? 'حفظ التقدم' : 'Save progress'),
        );
        await t.pumpAndSettle();
        expect(
          s.decode(s.data).growth.records.single.quality,
          FocusQuality.half,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
