import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader('GrowzaArabic')..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/NotoNaskhArabic-Regular.ttf').readAsBytesSync(),
          ),
        ),
      ))
      .load();
  final latin = File(
    'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
  );
  if (latin.existsSync()) {
    await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(latin.readAsBytesSync()))))
        .load();
  }
  final icons = File(
    'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );
  await testMain();
}
