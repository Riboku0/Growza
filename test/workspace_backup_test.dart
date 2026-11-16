import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growza/workspace_backup.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';
import 'package:growza/growth_ledger.dart';
import 'package:growza/focus_record.dart';
import 'package:growza/growth_rules.dart';

StudyWorkspace workspace({
  String id = 'subject',
  String name = 'Biology',
  String recordId = 'focus',
  int minutes = 10,
}) {
  final start = DateTime(2026, 11, 15, 10);
  return StudyWorkspace(
    subjects: [
      StudySubject(name, DateTime(2026, 12, 1), [
        const StudyPart(
          7,
          'Cells',
          40,
          completed: true,
          startPage: 2,
          endPage: 11,
        ),
      ], id: id),
    ],
    growth: GrowthLedger([
      FocusRecord(
        id: recordId,
        subjectId: id,
        planned: const Duration(minutes: 25),
        endedAt: start.add(Duration(minutes: minutes)),
        spans: [FocusSpan(start, start.add(Duration(minutes: minutes)))],
        completed: false,
        quality: FocusQuality.half,
      ),
    ]),
    focusCount: 2,
    recentSubjects: [name],
    languageCode: 'en',
    darkMode: true,
  );
}

void main() {
  test('backup round trip retains all study data including quality, IDs and PDF pages', () {
    final original = workspace();
    final restored = WorkspaceBackup.parse(WorkspaceBackup.export(original));
    expect(
      const StudyStorage().encode(restored),
      const StudyStorage().encode(original),
    );
    expect(WorkspaceBackup.export(original), isNot(contains('access_token')));
  });
  test('merge is idempotent and keeps current settings and quality', () {
    final current = workspace();
    final incoming = workspace()..languageCode = 'ar';
    final result = WorkspaceBackup.merge(current, incoming);
    expect(result.languageCode, 'en');
    expect(result.growth.records, hasLength(1));
    expect(
      const StudyStorage().encode(WorkspaceBackup.merge(result, incoming)),
      const StudyStorage().encode(result),
    );
  });
  test(
    'same name with different ID is renamed without changing IDs or history',
    () {
      final current = workspace();
      final incoming = workspace(id: 'other', recordId: 'other-focus');
      final result = WorkspaceBackup.merge(current, incoming);
      expect(result.subjects.last.name, 'Biology (2)');
      expect(result.subjects.last.id, 'other');
      expect(result.growth.records.last.subjectId, 'other');
      expect(current.subjects, hasLength(1));
    },
  );
  test('conflicting immutable focus record rejects merge without touching current data', () {
    final current = workspace();
    final before = const StudyStorage().encode(current);
    expect(
      () => WorkspaceBackup.merge(current, workspace(minutes: 20)),
      throwsA(isA<BackupException>()),
    );
    expect(const StudyStorage().encode(current), before);
  });
  test('invalid version, duplicate topic/record IDs and corrupt snapshots are rejected', () {
    final source = jsonDecode(WorkspaceBackup.export(workspace())) as Map;
    for (final change in <void Function(Map)>[
      (m) => m['version'] = 99,
      (m) => m['workspace']['subjects'][0]['parts'].add(
        m['workspace']['subjects'][0]['parts'][0],
      ),
      (m) => m['workspace']['growth']['records'].add(
        m['workspace']['growth']['records'][0],
      ),
      (m) => m['workspace']['subjects'][0]['parts'][0]['startPage'] = -1,
    ]) {
      final data = jsonDecode(jsonEncode(source)) as Map;
      change(data);
      expect(
        () => WorkspaceBackup.parse(jsonEncode(data)),
        throwsA(isA<BackupException>()),
      );
    }
    expect(
      () => WorkspaceBackup.parse('invalid'),
      throwsA(isA<BackupException>()),
    );
  });
  test('oversized backup is rejected before decode', () {
    expect(
      () => WorkspaceBackup.parse('x' * (WorkspaceBackup.maxBytes + 1)),
      throwsA(isA<BackupException>()),
    );
  });
}
