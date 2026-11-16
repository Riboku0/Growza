import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/app_theme.dart';
import 'package:growza/growth_rules.dart';
import 'package:growza/plant_visual.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';

import '../../test/frontend_completion_test.dart' as previews;

void main() {
  testWidgets(
    'Render Calculus II relative stages using the actual production painter',
    (t) async {
      await (FontLoader('GrowzaArabic')..addFont(
            rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'),
          ))
          .load();
      final latin = File(
        'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      );
      if (latin.existsSync()) {
        await (FontLoader('Roboto')..addFont(
              Future.value(ByteData.sublistView(latin.readAsBytesSync())),
            ))
            .load();
      }
      const size = Size(1080, 580);
      await t.binding.setSurfaceSize(size);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = size;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        return t.binding.setSurfaceSize(null);
      });
      final subject = StudySubject('Calculus II', DateTime(2026, 12, 1), [
        const StudyPart(1, 'Integration', 45),
        const StudyPart(2, 'Series', 60),
        const StudyPart(3, 'Applications', 75),
        const StudyPart(4, 'Practice', 120),
      ]);
      final target = StudyWorkspace().targetFor(subject);
      expect(target, const Duration(minutes: 600));
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture-root'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar', 'SA'),
            supportedLocales: const [Locale('ar', 'SA')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: buildGrowzaTheme(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(32, 24, 32, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Calculus II · مراحل النمو',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'معاينة توضيحية: تقديرات المواضيع 45 + 60 + 75 + 120 = 300 دقيقة',
                      style: TextStyle(
                        fontSize: 19,
                        color: GrowzaPalette.light.secondaryText,
                      ),
                    ),
                    Text(
                      'الهدف = 300 × ${GrowthRules.targetMultiplier} = ${target.inMinutes} دقيقة · الحد الأدنى ${GrowthRules.minTarget} دقيقة',
                      style: const TextStyle(fontSize: 19),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final stage in PlantStage.values)
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: PlantView(
                                      stage: stage,
                                      flowerCount: 0,
                                      state: PlantVisualState.calm,
                                    ),
                                  ),
                                  Text(
                                    GrowthRules.stageNames[stage]!,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${GrowthRules.stageThreshold(stage, target: target).inMinutes} دقيقة · ${(GrowthRules.stageFractions[stage]! * 100).round()}%',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'هذه معاينة للنمو بالتركيز؛ الأزهار تظهر مستقلةً بحسب المواضيع المنجزة.',
                      style: TextStyle(
                        fontSize: 17,
                        color: GrowzaPalette.light.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(PlantView), findsNWidgets(5));
      expect(t.takeException(), isNull);
      await previews.capture(t, 'Calculus-II-Stages');
    },
  );
}
