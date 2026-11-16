import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growza/growth_rules.dart';
import 'package:growza/focus_record.dart';
import 'package:growza/growth_ledger.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';

FocusRecord session(
  String id,
  DateTime start,
  int minutes, {
  String subject = 'calc',
  FocusQuality quality = FocusQuality.full,
  bool completed = true,
  int? planned,
}) => FocusRecord(
  id: id,
  subjectId: subject,
  planned: Duration(minutes: planned ?? minutes),
  endedAt: start.add(Duration(minutes: minutes)),
  spans: [FocusSpan(start, start.add(Duration(minutes: minutes)))],
  completed: completed,
  quality: quality,
);
PlantGrowth growth(
  GrowthLedger ledger, {
  String subject = 'calc',
  Duration target = GrowthRules.fallbackTarget,
}) => ledger.forSubject(
  subject,
  now: DateTime(2026, 11, 15, 18),
  exam: DateTime(2026, 12, 1),
  completedTopics: 0,
  totalTopics: 4,
  target: target,
);

void main() {
  test('Small subject takes 300-minute minimum including exact boundary', () {
    expect(GrowthRules.targetMultiplier, 2.0);
    expect(GrowthRules.minTarget, 300);
    for (final estimate in [1, 25, 149, 150]) {
      expect(
        GrowthRules.targetForEstimates([estimate]),
        const Duration(minutes: 300),
      );
    }
    expect(GrowthRules.targetForEstimates([151]), const Duration(minutes: 302));
  });
  test('Large Calculus II subject takes the 2.0 multiplier, not minimum', () {
    expect(
      GrowthRules.targetForEstimates([45, 60, 75, 120]),
      const Duration(minutes: 600),
    );
    expect(
      GrowthRules.targetForEstimates([720, 720]),
      const Duration(minutes: 2880),
    );
  });
  test('Empty subjects retain 1200; invalid old estimates are safe without division by zero', () {
    expect(GrowthRules.targetForEstimates([]), const Duration(minutes: 1200));
    expect(
      GrowthRules.targetForEstimates([0, -25]),
      const Duration(minutes: 300),
    );
    expect(
      GrowthRules.progressWithinStage(
        Duration.zero,
        target: GrowthRules.targetForEstimates([]),
      ),
      0,
    );
    expect(
      () =>
          GrowthRules.stageThreshold(PlantStage.sprout, target: Duration.zero),
      throwsArgumentError,
    );
  });
  test('All relative stage boundaries and continuous progress use 0/5/20/50/100 percent', () {
    for (final (target, thresholds) in [
      (300, [0, 15, 60, 150, 300]),
      (600, [0, 30, 120, 300, 600]),
    ]) {
      final goal = Duration(minutes: target);
      for (final stage in PlantStage.values) {
        final threshold = Duration(minutes: thresholds[stage.index]);
        expect(GrowthRules.stageThreshold(stage, target: goal), threshold);
        expect(GrowthRules.stageFor(threshold, target: goal), stage);
        if (stage != PlantStage.seed) {
          expect(
            GrowthRules.stageFor(
              threshold - const Duration(microseconds: 1),
              target: goal,
            ),
            PlantStage.values[stage.index - 1],
          );
        }
      }
      expect(
        GrowthRules.progressWithinStage(
          Duration(minutes: target * 2),
          target: goal,
        ),
        1,
      );
    }
    expect(
      GrowthRules.progressWithinStage(
        const Duration(minutes: 75),
        target: const Duration(minutes: 600),
      ),
      closeTo(.5, 1e-9),
    );
  });
  test('Quality scales growth 100/60/25 while actual statistics and record identity stay full', () {
    final date = DateTime(2026, 11, 15, 10);
    for (final (quality, credit) in [
      (FocusQuality.full, 20),
      (FocusQuality.half, 12),
      (FocusQuality.distracted, 5),
    ]) {
      final original = session('stable-id', date, 20);
      final ledger = GrowthLedger([original]);
      expect(ledger.setQuality(original.id, quality), isTrue);
      expect(growth(ledger).credited, Duration(minutes: credit));
      expect(ledger.totalFocused, const Duration(minutes: 20));
      final record = ledger.records.single;
      expect(record.id, original.id);
      expect(
        record.spans.map((s) => s.toJson()),
        original.spans.map((s) => s.toJson()),
      );
      expect(record.completed, original.completed);
      expect(ledger.forDay(date).budgetUsed, const Duration(minutes: 20));
      expect(ledger.add(original), isFalse);
      expect(ledger.records.single.quality, quality);
    }
    expect(GrowthLedger().setQuality('missing', FocusQuality.half), isFalse);
  });
  test('Five-minute eligibility is actual time before quality, including partial sessions', () {
    final date = DateTime(2026, 11, 15, 10);
    final short = FocusRecord(
      id: 'short',
      subjectId: 'calc',
      planned: const Duration(minutes: 25),
      endedAt: date.add(const Duration(minutes: 4, seconds: 59)),
      spans: [
        FocusSpan(date, date.add(const Duration(minutes: 4, seconds: 59))),
      ],
      completed: false,
      quality: FocusQuality.half,
    );
    final ledger = GrowthLedger([
      short,
      session(
        'exact-five',
        date.add(const Duration(hours: 1)),
        5,
        planned: 25,
        completed: false,
        quality: FocusQuality.half,
      ),
    ]);
    expect(ledger.totalFocused, const Duration(minutes: 9, seconds: 59));
    expect(growth(ledger).credited, const Duration(minutes: 3));
  });
  test('Pause gaps remain excluded under quality scaling', () {
    final date = DateTime(2026, 11, 15, 10);
    final record = FocusRecord(
      id: 'paused',
      subjectId: 'calc',
      planned: const Duration(minutes: 25),
      endedAt: date.add(const Duration(minutes: 36)),
      spans: [
        FocusSpan(date, date.add(const Duration(minutes: 2))),
        FocusSpan(
          date.add(const Duration(minutes: 32)),
          date.add(const Duration(minutes: 36)),
        ),
      ],
      completed: false,
      quality: FocusQuality.distracted,
    );
    final ledger = GrowthLedger([record]);
    expect(ledger.totalFocused, const Duration(minutes: 6));
    expect(growth(ledger).credited, const Duration(minutes: 1, seconds: 30));
    expect(ledger.forDay(date).budgetUsed, const Duration(minutes: 6));
  });
  test(
    'Shared 240-minute cap consumes actual eligible time regardless of quality',
    () {
      final date = DateTime(2026, 11, 15, 8);
      final ledger = GrowthLedger([
        session('a', date, 150, quality: FocusQuality.half),
        session(
          'b',
          date.add(const Duration(hours: 3)),
          100,
          subject: 'physics',
          quality: FocusQuality.distracted,
        ),
        session('c', date.add(const Duration(hours: 6)), 30),
      ]);
      final day = ledger.forDay(date);
      expect(day.focused, const Duration(minutes: 280));
      expect(day.budgetUsed, const Duration(minutes: 240));
      expect(day.credited, const Duration(minutes: 112, seconds: 30));
      expect(day.remaining, Duration.zero);
      expect(day.limitReached, isTrue);
      expect(day.message, GrowthRules.dailyLimitMessage);
      expect(growth(ledger).credited, const Duration(minutes: 90));
      expect(
        growth(ledger, subject: 'physics').credited,
        const Duration(minutes: 22, seconds: 30),
      );
      ledger.setQuality('a', FocusQuality.distracted);
      expect(ledger.forDay(date).budgetUsed, const Duration(minutes: 240));
      expect(growth(ledger).credited, const Duration(minutes: 37, seconds: 30));
      expect(ledger.records, hasLength(3));
    },
  );
  test('Quality and actual shared budget split at local midnight', () {
    final day = DateTime(2026, 11, 15);
    final ledger = GrowthLedger([
      session('earlier', DateTime(2026, 11, 15, 10), 235),
      session(
        'midnight',
        DateTime(2026, 11, 15, 23, 50),
        20,
        quality: FocusQuality.half,
      ),
    ]);
    expect(ledger.forDay(day).budgetUsed, const Duration(minutes: 240));
    expect(ledger.forDay(day).credited, const Duration(minutes: 238));
    expect(ledger.forDay(day).focused, const Duration(minutes: 245));
    final next = ledger.forDay(DateTime(2026, 11, 16));
    expect(next.budgetUsed, const Duration(minutes: 10));
    expect(next.focused, const Duration(minutes: 10));
    expect(next.credited, const Duration(minutes: 6));
  });
  test('Optional legacy quality defaults Full, preserves IDs/spans and rejects unknown values', () {
    final original = session('legacy-id', DateTime(2026, 11, 15, 10), 25);
    final old = original.toJson()..remove('quality');
    final restored = FocusRecord.fromJson(old);
    expect(restored.quality, FocusQuality.full);
    expect(restored.id, 'legacy-id');
    expect(restored.spans.single.toJson(), original.spans.single.toJson());
    for (final q in FocusQuality.values) {
      final roundTrip = FocusRecord.fromJson(restored.withQuality(q).toJson());
      expect(roundTrip.quality, q);
      expect(roundTrip.id, 'legacy-id');
    }
    expect(
      () => FocusRecord.fromJson({...old, 'quality': 'unrecognized'}),
      throwsFormatException,
    );
  });
  test('Topic estimate edits change target and stage without deleting credited historical minutes', () {
    final subject = StudySubject('Calculus II', DateTime(2026, 12, 1), [
      const StudyPart(1, 'Integration', 25),
    ]);
    final record = session(
      'kept-record',
      DateTime(2026, 11, 14, 10),
      90,
      subject: subject.id,
    );
    final workspace = StudyWorkspace(
      subjects: [subject],
      growth: GrowthLedger([record]),
    );
    final before = workspace.growthFor(subject, DateTime(2026, 11, 15));
    expect(before.target, const Duration(minutes: 300));
    expect(before.stage, PlantStage.plant);
    final changed = subject.withParts([const StudyPart(1, 'Integration', 600)]);
    workspace.subjects[0] = changed;
    final after = workspace.growthFor(changed, DateTime(2026, 11, 15));
    expect(after.target, const Duration(minutes: 1200));
    expect(after.stage, PlantStage.sprout);
    expect(after.credited, before.credited);
    expect(after.focused, before.focused);
    expect(workspace.growth.records.single.id, record.id);
    final empty = changed.withParts([]);
    expect(
      workspace.growthFor(empty, DateTime(2026, 11, 15)).target,
      const Duration(minutes: 1200),
    );
    expect(
      workspace.growthFor(empty, DateTime(2026, 11, 15)).credited,
      const Duration(minutes: 90),
    );
  });
  test('Legacy workspace data and focus IDs survive repeated migration and quality review', () {
    final subject = StudySubject('Calculus II', DateTime(2026, 12, 1), [
      const StudyPart(7, 'Integration', 60, completed: true),
    ], pdfName: 'calculus.pdf');
    const storage = StudyStorage();
    final initial = StudyWorkspace(
      subjects: [subject],
      growth: GrowthLedger([
        session('old', DateTime(2026, 11, 14, 10), 60, subject: subject.id),
      ]),
    );
    final old = jsonDecode(storage.encode(initial)) as Map<String, dynamic>;
    (old['growth']['records'] as List).single.remove('quality');
    var workspace = storage.decode(jsonEncode(old));
    final subjects = jsonEncode(old['subjects']);
    for (var i = 0; i < 3; i++) {
      expect(workspace.growth.records.single.quality, FocusQuality.full);
      expect(
        workspace
            .growthFor(workspace.subjects.single, DateTime(2026, 11, 15))
            .credited,
        const Duration(minutes: 60),
      );
      expect(
        jsonEncode(workspace.subjects.map((s) => s.toJson()).toList()),
        subjects,
      );
      expect(workspace.growth.records.single.id, 'old');
      workspace = storage.decode(storage.encode(workspace));
    }
  });
  test('Gentle streak uses actual local-day focus and loses no growth when a day is missed', () {
    final ledger = GrowthLedger([
      session(
        'yesterday',
        DateTime(2026, 11, 14, 10),
        10,
        quality: FocusQuality.distracted,
      ),
      session(
        'today',
        DateTime(2026, 11, 15, 10),
        5,
        quality: FocusQuality.half,
      ),
    ]);
    expect(ledger.currentStreak(DateTime(2026, 11, 15, 12)), 2);
    expect(ledger.currentStreak(DateTime(2026, 11, 16, 12)), 2);
    final credited = growth(ledger).credited;
    expect(ledger.currentStreak(DateTime(2026, 11, 17, 12)), 0);
    expect(growth(ledger).credited, credited);
    ledger.add(session('new-day', DateTime(2026, 11, 17, 13), 5));
    expect(ledger.currentStreak(DateTime(2026, 11, 17, 14)), 1);
  });
  test('Streak counts accumulated actual minutes without treating pause gaps as focus', () {
    final date = DateTime(2026, 11, 15, 10);
    final ledger = GrowthLedger([
      session('two', date, 2, planned: 25, completed: false),
      session(
        'three',
        date.add(const Duration(hours: 2)),
        3,
        planned: 25,
        completed: false,
      ),
    ]);
    expect(ledger.currentStreak(date.add(const Duration(hours: 3))), 1);
    expect(growth(ledger).credited, Duration.zero);
    expect(
      GrowthLedger([session('four', date, 4, planned: 25, completed: false)])
          .currentStreak(date.add(const Duration(hours: 1))),
      0,
    );
  });
}
