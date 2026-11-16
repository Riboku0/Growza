import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';

void main() {
  test('Older workspaces recover recent studied subjects without including future plans', () {
    const storage = StudyStorage();
    final original = StudyWorkspace(
      sessions: [
        StudySession(
          'Mathematics',
          'First part',
          DateTime(2026, 11, 9),
          25,
          completed: true,
        ),
        StudySession(
          'Physics',
          'Mechanics',
          DateTime(2026, 11, 10),
          25,
          completed: true,
        ),
        StudySession(
          'Mathematics',
          'Earlier part',
          DateTime(2026, 11, 8),
          25,
          completed: true,
        ),
        StudySession('Chemistry', 'Future plan', DateTime(2026, 11, 13), 25),
      ],
      focusCount: 3,
    );
    final legacy = jsonDecode(storage.encode(original)) as Map<String, dynamic>;
    legacy.remove('recentSubjects');
    final recovered = storage.decode(jsonEncode(legacy));
    expect(recovered.recentSubjects, ['Physics', 'Mathematics']);
    expect(recovered.focusCount, 3);
    expect(recovered.sessions, hasLength(4));
    recovered.recentSubjects
      ..remove('Mathematics')
      ..insert(0, 'Mathematics');
    expect(storage.decode(storage.encode(recovered)).recentSubjects, [
      'Mathematics',
      'Physics',
    ]);
  });
}
