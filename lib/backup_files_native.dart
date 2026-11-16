import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

Future<bool> saveBackupFile(String text, String name) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return await const MethodChannel('growza/files')
            .invokeMethod<bool>('saveText', {'name': name, 'text': text}) ??
        false;
  }
  final location = await getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: [
      const XTypeGroup(label: 'Growza backup', extensions: ['json']),
    ],
  );
  if (location == null) return false;
  await XFile.fromData(
    utf8.encode(text),
    mimeType: 'application/json',
    name: name,
  ).saveTo(location.path);
  return true;
}
