import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/app_theme.dart';
import 'package:growza/growth_rules.dart';
import 'package:growza/plant_visual.dart';

import 'frontend_completion_test.dart' as previews;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Botanical stages stay distinct and fit the $brightness gallery',
      (t) async {
        await t.binding.setSurfaceSize(const Size(1200, 620));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture-root'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildGrowzaTheme(brightness: brightness),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 40, 40, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Growza',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                          color: brightness == Brightness.dark
                              ? GrowzaPalette.dark.foreground
                              : ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Focus grows the stem. Completed topics bring the garden into bloom.',
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final stage in PlantStage.values)
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: PlantView(
                                        stage: stage,
                                        flowerCount: [
                                          0,
                                          0,
                                          2,
                                          3,
                                          6,
                                        ][stage.index],
                                        centered: false,
                                        animate: false,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      [
                                        'Seed',
                                        'Sprout',
                                        'Plant',
                                        'Shrub',
                                        'Tree',
                                      ][stage.index],
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      [
                                        'بذرة',
                                        'برعم',
                                        'نبتة',
                                        'شجيرة',
                                        'شجرة',
                                      ][stage.index],
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),
                          ],
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
        expect(t.takeException(), isNull);
        await previews.capture(
          t,
          'Botanical-Stages-${brightness == Brightness.dark ? 'Dark' : 'Light'}',
        );
      },
    );
  }
}
