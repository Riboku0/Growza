import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growza/focus_record.dart';
import 'package:growza/growth_ledger.dart';
import 'package:growza/growth_rules.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';

FocusRecord record(
  String id,
  String? subject,
  DateTime start,
  Duration focused, {
  Duration? planned,
  bool completed = true,
}) => FocusRecord(
  id: id,
  subjectId: subject,
  planned: planned ?? focused,
  endedAt: start.add(focused),
  spans: [FocusSpan(start, start.add(focused))],
  completed: completed,
);
PlantGrowth plant(
  GrowthLedger ledger,
  String id, {
  DateTime? now,
  DateTime? exam,
  int done = 0,
  int topics = 4,
  bool active = false,
}) => ledger.forSubject(
  id,
  now: now ?? DateTime(2026, 11, 14, 18),
  exam: exam ?? DateTime(2026, 12, 1),
  completedTopics: done,
  totalTopics: topics,
  isFocusing: active,
);

void main() {
  test('Stage thresholds use exact cumulative credited minutes', () {
    for (final (minutes, expected) in [
      (0, PlantStage.seed),
      (59, PlantStage.seed),
      (60, PlantStage.sprout),
      (239, PlantStage.sprout),
      (240, PlantStage.plant),
      (599, PlantStage.plant),
      (600, PlantStage.shrub),
      (1199, PlantStage.shrub),
      (1200, PlantStage.tree),
    ]) {
      expect(GrowthRules.stageFor(Duration(minutes: minutes)), expected);
    }
    expect(
      GrowthRules.stageFor(
        const Duration(minutes: 60) - const Duration(milliseconds: 1),
      ),
      PlantStage.seed,
    );
    expect(
      GrowthRules.progressWithinStage(const Duration(minutes: 30)),
      closeTo(0.5, 0.00001),
    );
    expect(GrowthRules.progressWithinStage(const Duration(minutes: 2000)), 1);
  });

  test('Short interruptions remain statistics; five-minute and fractional sessions grow proportionally', () {
    final start = DateTime(2026, 11, 14, 10);
    final ledger = GrowthLedger([
      record(
        'short',
        'math',
        start,
        const Duration(minutes: 4, seconds: 59),
        planned: const Duration(minutes: 25),
        completed: false,
      ),
      record(
        'five',
        'math',
        start.add(const Duration(hours: 1)),
        const Duration(minutes: 5),
        planned: const Duration(minutes: 25),
        completed: false,
      ),
      record(
        'fractional',
        'math',
        start.add(const Duration(hours: 2)),
        const Duration(minutes: 6, seconds: 30),
        planned: const Duration(minutes: 25),
        completed: false,
      ),
    ]);
    expect(ledger.totalFocused, const Duration(minutes: 16, seconds: 29));
    expect(
      plant(ledger, 'math').credited,
      const Duration(minutes: 11, seconds: 30),
    );
    expect(plant(ledger, 'math').focused, ledger.totalFocused);
  });

  test('Daily growth cap is shared across subjects while statistics and topic progress continue', () {
    final day = DateTime(2026, 11, 14);
    final ledger = GrowthLedger([
      record(
        'first',
        'math',
        DateTime(2026, 11, 14, 8),
        const Duration(minutes: 200),
      ),
      record(
        'second',
        'physics',
        DateTime(2026, 11, 14, 12),
        const Duration(minutes: 80),
      ),
      record(
        'third',
        'biology',
        DateTime(2026, 11, 14, 14),
        const Duration(minutes: 30),
      ),
    ]);
    expect(plant(ledger, 'math').credited, const Duration(minutes: 200));
    expect(plant(ledger, 'physics').credited, const Duration(minutes: 40));
    expect(plant(ledger, 'biology', done: 2).credited, Duration.zero);
    expect(plant(ledger, 'biology', done: 2).topicProgress, 0.5);
    final summary = ledger.forDay(day);
    expect(summary.focused, const Duration(minutes: 310));
    expect(summary.credited, const Duration(minutes: 240));
    expect(summary.remaining, Duration.zero);
    expect(summary.limitReached, isTrue);
    expect(summary.message, GrowthRules.dailyLimitMessage);
    ledger.add(
      record(
        'tomorrow',
        'biology',
        DateTime(2026, 11, 15, 8),
        const Duration(minutes: 25),
      ),
    );
    expect(
      ledger.forDay(DateTime(2026, 11, 15)).credited,
      const Duration(minutes: 25),
    );
    expect(ledger.forDay(DateTime(2026, 11, 15)).limitReached, isFalse);
    expect(ledger.forDay(DateTime(2026, 11, 15)).message, isNull);
  });

  test('Growth and statistics split at local midnight instead of using the completion day', () {
    final ledger = GrowthLedger([
      record(
        'earlier',
        'math',
        DateTime(2026, 11, 14, 9),
        const Duration(minutes: 239),
      ),
      record(
        'midnight',
        'physics',
        DateTime(2026, 11, 14, 23, 58),
        const Duration(minutes: 6),
      ),
    ]);
    expect(
      ledger.forDay(DateTime(2026, 11, 14)).focused,
      const Duration(minutes: 241),
    );
    expect(
      ledger.forDay(DateTime(2026, 11, 14)).credited,
      const Duration(minutes: 240),
    );
    expect(
      ledger.forDay(DateTime(2026, 11, 15)).focused,
      const Duration(minutes: 4),
    );
    expect(
      ledger.forDay(DateTime(2026, 11, 15)).credited,
      const Duration(minutes: 4),
    );
    expect(plant(ledger, 'physics').focused, const Duration(minutes: 6));
    expect(plant(ledger, 'physics').credited, const Duration(minutes: 5));
  });

  test('Paused time across midnight and general study never grow an unrelated plant', () {
    final ledger = GrowthLedger([
      FocusRecord(
        id: 'paused',
        subjectId: 'math',
        planned: const Duration(minutes: 25),
        endedAt: DateTime(2026, 11, 15, 0, 25),
        completed: false,
        spans: [
          FocusSpan(
            DateTime(2026, 11, 14, 23, 50),
            DateTime(2026, 11, 14, 23, 55),
          ),
          FocusSpan(
            DateTime(2026, 11, 15, 0, 20),
            DateTime(2026, 11, 15, 0, 25),
          ),
        ],
      ),
      record(
        'general',
        null,
        DateTime(2026, 11, 15, 10),
        const Duration(minutes: 25),
      ),
    ]);
    expect(ledger.totalFocused, const Duration(minutes: 35));
    expect(plant(ledger, 'math').credited, const Duration(minutes: 10));
    expect(plant(ledger, 'other').credited, Duration.zero);
    expect(
      ledger.forDay(DateTime(2026, 11, 15)).focused,
      const Duration(minutes: 30),
    );
    expect(
      ledger.forDay(DateTime(2026, 11, 15)).credited,
      const Duration(minutes: 5),
    );
  });

  test('Replay and JSON roundtrips do not award a focus session twice', () {
    final item = record(
      'same-id',
      'math',
      DateTime(2026, 11, 14, 10),
      const Duration(minutes: 25),
    );
    final ledger = GrowthLedger([item]);
    expect(ledger.add(item), isFalse);
    final restored = GrowthLedger.fromJson(
      jsonDecode(jsonEncode(ledger.toJson())) as Map<String, dynamic>,
    );
    expect(restored.add(item), isFalse);
    expect(restored.records, hasLength(1));
    expect(restored.totalFocused, const Duration(minutes: 25));
  });

  test('Absence never reduces growth; activity wakes the plant without resetting topics', () {
    final ledger = GrowthLedger([
      record(
        'done',
        'math',
        DateTime(2026, 11, 14, 8),
        const Duration(minutes: 240),
      ),
    ]);
    final before = plant(ledger, 'math', done: 3);
    final later = plant(ledger, 'math', now: DateTime(2026, 11, 20), done: 3);
    expect(later.credited, before.credited);
    expect(later.stage, before.stage);
    expect(later.topicProgress, before.topicProgress);
    expect(before.resting, isFalse);
    expect(later.resting, isTrue);
    expect(
      plant(ledger, 'math', now: DateTime(2026, 11, 20), active: true).resting,
      isFalse,
    );
  });

  test('Harvest eligibility respects timed and all-day exams without deleting growth', () {
    final ledger = GrowthLedger([
      record(
        'done',
        'math',
        DateTime(2026, 11, 14, 8),
        const Duration(minutes: 60),
      ),
    ]);
    final exam = DateTime(2026, 11, 15, 10);
    expect(
      plant(
        ledger,
        'math',
        exam: exam,
        now: exam.subtract(const Duration(seconds: 1)),
      ).harvested,
      isFalse,
    );
    final harvested = plant(ledger, 'math', exam: exam, now: exam);
    expect(harvested.harvested, isTrue);
    expect(harvested.credited, const Duration(minutes: 60));
    expect(
      plant(
        ledger,
        'math',
        exam: DateTime(2026, 11, 15),
        now: DateTime(2026, 11, 15, 23, 59),
      ).harvested,
      isFalse,
    );
    expect(
      plant(
        ledger,
        'math',
        exam: DateTime(2026, 11, 15),
        now: DateTime(2026, 11, 16),
      ).harvested,
      isTrue,
    );
  });

  test(
    'Old completed sessions migrate once and preserve subject and topic data',
    () {
      const storage = StudyStorage();
      final subject = StudySubject('Math', DateTime(2026, 12, 1), [
        const StudyPart(1, 'Algebra', 25, completed: true),
        const StudyPart(2, 'Calculus', 35),
      ], pdfName: 'notes.pdf');
      final original = StudyWorkspace(
        subjects: [subject],
        focusCount: 2,
        sessions: [
          StudySession(
            'Math',
            'Algebra',
            DateTime(2026, 11, 12, 10),
            25,
            partId: 1,
            completed: true,
          ),
          StudySession(
            'Math',
            'Calculus',
            DateTime(2026, 11, 13, 10),
            35,
            partId: 2,
            completed: true,
          ),
          StudySession(
            'Math',
            'Future plan',
            DateTime(2026, 11, 20, 10),
            25,
            partId: 2,
          ),
        ],
      );
      final old = jsonDecode(storage.encode(original)) as Map<String, dynamic>;
      old.remove('growth');
      (old['subjects'] as List).single.remove('id');
      var migrated = storage.decode(jsonEncode(old));
      final migratedId = migrated.subjects.single.id;
      for (var reload = 0; reload < 3; reload++) {
        final savedSubject = migrated.subjects.single;
        expect(savedSubject.name, subject.name);
        expect(savedSubject.exam, subject.exam);
        expect(savedSubject.pdfName, subject.pdfName);
        expect(
          savedSubject.parts.map((p) => p.toJson()),
          subject.parts.map((p) => p.toJson()),
        );
        expect(savedSubject.id, migratedId);
        expect(migrated.growth.records, hasLength(2));
        expect(migrated.growth.records.every((r) => r.legacy), isTrue);
        expect(
          migrated.growthFor(savedSubject, DateTime(2026, 11, 14)).stage,
          PlantStage.plant,
        );
        expect(migrated.growth.totalFocused, const Duration(minutes: 60));
        expect(migrated.focusCount, 2);
        expect(migrated.sessions, hasLength(3));
        migrated = storage.decode(storage.encode(migrated));
      }
    },
  );

  test('Historical focus reaches a mature stage and still follows the shared daily cap', () {
    final subject = StudySubject('Math', DateTime(2026, 12, 1), []);
    final workspace = StudyWorkspace(
      subjects: [subject],
      sessions: [
        for (var day = 1; day <= 5; day++)
          StudySession(
            'Math',
            'Old focus',
            DateTime(2026, 11, day, 8),
            300,
            completed: true,
          ),
      ],
    );
    expect(workspace.growth.totalFocused, const Duration(minutes: 1500));
    final growth = workspace.growthFor(subject, DateTime(2026, 11, 14));
    expect(growth.credited, const Duration(minutes: 1200));
    expect(growth.stage, PlantStage.tree);
  });

  test('Renaming preserves growth; deleting and reusing a name cannot reset the daily budget', () {
    final old = StudySubject('Math', DateTime(2026, 12, 1), []);
    final workspace = StudyWorkspace(
      subjects: [old],
      sessions: [
        StudySession(
          'Math',
          'Old focus',
          DateTime(2026, 11, 14, 8),
          60,
          completed: true,
        ),
      ],
    );
    final renamed = StudySubject('Analysis', old.exam, old.parts, id: old.id);
    workspace.subjects[0] = renamed;
    expect(
      workspace.growthFor(renamed, DateTime(2026, 11, 14)).credited,
      const Duration(minutes: 60),
    );
    final replacement = StudySubject('Math', old.exam, []);
    workspace.subjects[0] = replacement;
    expect(
      workspace.growthFor(replacement, DateTime(2026, 11, 14)).credited,
      Duration.zero,
    );
    expect(
      workspace.growth.forDay(DateTime(2026, 11, 14)).credited,
      const Duration(minutes: 60),
    );
  });

  test('A new workspace has no fabricated focus and a new subject starts as a seed', () {
    final workspace = StudyWorkspace();
    expect(workspace.subjects, isEmpty);
    expect(workspace.growth.records, isEmpty);
    final first = StudySubject('First subject', DateTime(2026, 12, 1), []);
    workspace.subjects.add(first);
    final growth = workspace.growthFor(first, DateTime(2026, 11, 14));
    expect(growth.stage, PlantStage.seed);
    expect(growth.credited, Duration.zero);
    expect(growth.topicProgress, 0);
  });
}
