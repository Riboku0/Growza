import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'study_database.dart';

Future<StudyDatabase>? _opening;
Future<StudyDatabase> _store() => _opening ??=
    () async {
      final directory = await getApplicationSupportDirectory();
      return StudyDatabase(
        path: '${directory.path}${Platform.pathSeparator}growza-study.db',
      );
    }().catchError((Object error) {
      _opening = null;
      throw error;
    });
Future<String?> readWorkspace({
  required String Function(String?) normalize,
}) async {
  final store = await _store();
  return store.readOrMigrate(
    normalize: normalize,
    readLegacy: () async {
      final directory = await getApplicationSupportDirectory();
      final legacy = File(
        '${directory.path}${Platform.pathSeparator}istudy-workspace.json',
      );
      return await legacy.exists() ? legacy.readAsString() : null;
    },
  );
}

Future<void> writeWorkspace(String snapshot) async =>
    (await _store()).write(snapshot);
