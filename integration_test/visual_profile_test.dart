import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:growza/main.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';
import 'package:growza/motion.dart';

class _Memory extends StudyStorage {
  late String snapshot;
  @override
  Future<StudyWorkspace> load() async => decode(snapshot);
  @override
  Future<void> save(String value) async {
    snapshot = value;
  }
}

void main() {
  const verification = bool.fromEnvironment('GROWZA_VERIFICATION');
  if (!verification) {
    throw StateError(
      'Run this fixture only in the isolated verification package.',
    );
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Profile the approved forest and quiet focus on a physical device',
    (tester) async {
      final now = DateTime.now();
      final memory = _Memory();
      memory.snapshot = memory.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('الأحياء', now.add(const Duration(days: 6)), [
              for (var i = 1; i <= 8; i++)
                StudyPart(i, 'الفصل $i', 25, completed: i <= 3),
            ]),
            StudySubject('الرياضيات', now.add(const Duration(days: 8)), [
              const StudyPart(1, 'التكامل', 25),
            ]),
          ],
          sessions: [
            for (var d = 1; d <= 6; d++)
              StudySession(
                'الأحياء',
                'جلسة سابقة',
                DateTime(now.year, now.month, now.day - d, 8),
                200,
                completed: true,
              ),
          ],
          recentSubjects: ['الأحياء'],
        ),
      );
      await tester.pumpWidget(GrowzaApp(showWelcome: false, storage: memory));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('home-progress-card')), findsOneWidget);
      final reduced = MediaQuery.of(
        tester.element(find.byKey(const ValueKey('home-progress-card'))),
      ).disableAnimations;
      expect(
        reduced,
        isFalse,
        reason:
            'Motion profiling needs the device reduce-motion setting disabled.',
      );
      Future<Map<String, Object>> sample() async {
        await Future<void>.delayed(const Duration(seconds: 3));
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> batch) {
          frames.addAll(batch);
        }

        WidgetsBinding.instance.addTimingsCallback(collect);
        final watch = Stopwatch()..start();
        await Future<void>.delayed(const Duration(seconds: 12));
        watch.stop();
        WidgetsBinding.instance.removeTimingsCallback(collect);
        expect(frames.length, greaterThan(30));
        double percentile(List<double> values) {
          values.sort();
          return values[((values.length - 1) * .95).round()];
        }

        final build = [
          for (final f in frames) f.buildDuration.inMicroseconds / 1000,
        ];
        final raster = [
          for (final f in frames) f.rasterDuration.inMicroseconds / 1000,
        ];
        return {
          'frames': frames.length,
          'seconds': watch.elapsedMilliseconds / 1000,
          'frames_per_second':
              frames.length / (watch.elapsedMilliseconds / 1000),
          'build_p95_ms': percentile(build),
          'raster_p95_ms': percentile(raster),
          'build_over_16_67ms': build.where((v) => v > 16.67).length,
          'raster_over_16_67ms': raster.where((v) => v > 16.67).length,
        };
      }

      final home = await sample();
      final start = find.byKey(const ValueKey('home-start-study'));
      await tester.ensureVisible(start);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('focus-clock')), findsOneWidget);
      final focus = await sample();
      expect(
        tester
            .stateList<MotionLoopState>(find.byType(MotionLoop))
            .any((s) => s.isAnimating),
        isTrue,
      );
      binding.reportData = {
        'mode': 'profile',
        'isolated_memory_fixture': true,
        'home': home,
        'focus': focus,
      };
    },
  );
}
