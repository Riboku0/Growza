import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 3),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    await File('.dart_tool/visual-profile-results.json')
        .writeAsString(jsonEncode(data));
  },
);
