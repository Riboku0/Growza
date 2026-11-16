import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:growza/backup_files.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native Android document picker writes a backup', (t) async {
    expect(const bool.fromEnvironment('GROWZA_VERIFICATION'), true);
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Growza Verification — backup export')),
        ),
      ),
    );
    final folder = await getApplicationSupportDirectory();
    final phase = File('${folder.path}/export-verification-phase');
    await phase.writeAsString('ready');
    final saved = await saveBackupFile(
      '{"verification":true}',
      'Growza-Verification-backup.json',
    );
    expect(saved, true);
    await phase.writeAsString('saved');
  }, skip: !const bool.fromEnvironment('GROWZA_EXPORT_SMOKE'));
}
