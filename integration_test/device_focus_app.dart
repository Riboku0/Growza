// Native lifecycle fixture. Never run in the student's application package.
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:growza/main.dart' as app;
import 'package:growza/focus_timer.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('GROWZA_VERIFICATION')) {
    throw StateError('Only the isolated verification package is permitted');
  }
  final folder = await getApplicationSupportDirectory();
  if (!folder.path.contains('/com.example.istudy.verification/')) {
    throw StateError('Unexpected native sandbox; no fixture data written');
  }
  final marker = File('${folder.path}/focus-lifecycle-v1.seeded');
  const storage = StudyStorage();
  if (!await marker.exists()) {
    // Health only: no credentials, enrollment or AI inference.
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(const String.fromEnvironment('GROWZA_WORKER_URL'))
                .resolve('/health'),
          )
          .timeout(const Duration(seconds: 15));
      await File('${folder.path}/focus-cloudflare-health.json').writeAsString(
        jsonEncode({
          'status': response.statusCode,
          'health': jsonDecode(response.body),
        }),
      );
    } catch (_) {
      await File('${folder.path}/focus-cloudflare-health.json')
          .writeAsString(jsonEncode({'networkFailure': true}));
    } finally {
      client.close();
    }
    final now = DateTime.now();
    final subject = StudySubject(
      'مادة التحقق من المؤقت',
      now.add(const Duration(days: 5)),
      [const StudyPart(1, 'موضوع اختباري', 25)],
      id: 'focus-lifecycle-subject',
    );
    final timer = FocusTimer(
      focusLength: const Duration(minutes: 25),
      subjectId: subject.id,
      onFocusCompleted: () {},
    )..toggle();
    final workspace = StudyWorkspace(
      subjects: [subject],
      languageCode: 'ar',
      darkMode: false,
      activeTimer: {
        'timer': timer.toJson(),
        'session': StudySession(
          subject.name,
          'موضوع اختباري',
          now,
          25,
          partId: 1,
        ).toJson(),
      },
    );
    timer.dispose();
    await storage.save(storage.encode(workspace));
    await marker.writeAsString(now.toUtc().toIso8601String());
  }
  runApp(const app.GrowzaApp(storage: storage, showWelcome: false));
}
