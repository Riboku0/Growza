import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 4),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    await File('.dart_tool/local-auth-native-results.json')
        .writeAsString(jsonEncode(data));
  },
);
