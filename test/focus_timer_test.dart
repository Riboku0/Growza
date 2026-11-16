import 'package:flutter_test/flutter_test.dart';
import 'package:growza/focus_timer.dart';
import 'package:growza/focus_record.dart';
import 'package:growza/growth_ledger.dart';
import 'package:growza/growth_rules.dart';

void main() {
  test(
    'Running snapshot uses elapsed wall time and completes focus only once',
    () {
      var now = DateTime(2026, 11, 14, 12);
      var completions = 0;
      final first = FocusTimer(
        focusLength: const Duration(minutes: 25),
        now: () => now,
        onFocusCompleted: () => completions++,
      );
      first.toggle();
      final saved = first.toJson();
      first.dispose();
      now = now.add(const Duration(minutes: 10));
      final restored = FocusTimer.restore(
        saved,
        now: () => now,
        onFocusCompleted: () => completions++,
      );
      restored.refresh();
      expect(restored.isRunning, isTrue);
      expect(restored.remaining, const Duration(minutes: 15));
      now = now.add(const Duration(hours: 2));
      restored.refresh();
      restored.refresh();
      expect(restored.phase, TimerPhase.rest);
      expect(restored.remaining, studyBreak);
      expect(restored.isRunning, isFalse);
      expect(completions, 1);
      final breakSnapshot = restored.toJson();
      restored.dispose();
      final rest = FocusTimer.restore(
        breakSnapshot,
        now: () => now,
        onFocusCompleted: () => completions++,
      );
      rest.toggle();
      final runningBreak = rest.toJson();
      rest.dispose();
      now = now.add(const Duration(minutes: 6));
      final finished = FocusTimer.restore(
        runningBreak,
        now: () => now,
        onFocusCompleted: () => completions++,
      );
      finished.refresh();
      expect(finished.phase, TimerPhase.finished);
      expect(completions, 1);
      finished.dispose();
    },
  );

  test('Paused snapshot stays paused despite elapsed wall time', () {
    var now = DateTime(2026, 11, 14, 12);
    final timer = FocusTimer(
      focusLength: const Duration(minutes: 25),
      now: () => now,
      onFocusCompleted: () {},
    );
    timer.toggle();
    now = now.add(const Duration(minutes: 8));
    timer.toggle();
    final saved = timer.toJson();
    timer.dispose();
    now = now.add(const Duration(days: 1));
    final restored = FocusTimer.restore(
      saved,
      now: () => now,
      onFocusCompleted: () {},
    );
    restored.refresh();
    expect(restored.isRunning, isFalse);
    expect(restored.remaining, const Duration(minutes: 17));
    restored.reset();
    expect(restored.hasProgress, isFalse);
    restored.dispose();
  });
  test('Interrupted focus records active time and excludes every pause', () {
    var now = DateTime(2026, 11, 14, 10);
    final records = <FocusRecord>[];
    final timer = FocusTimer(
      focusLength: const Duration(minutes: 25),
      subjectId: 'math',
      now: () => now,
      onFocusCompleted: () {},
      onFocusRecorded: records.add,
    );
    addTearDown(timer.dispose);
    timer.toggle();
    now = now.add(const Duration(minutes: 3));
    timer.toggle();
    now = now.add(const Duration(hours: 1));
    expect(timer.focused, const Duration(minutes: 3));
    expect(records, isEmpty);
    timer.toggle();
    now = now.add(const Duration(minutes: 4));
    final result = timer.finishFocus()!;
    expect(result.completed, isFalse);
    expect(result.focused, const Duration(minutes: 7));
    expect(result.spans, hasLength(2));
    expect(records, hasLength(1));
    expect(timer.hasProgress, isFalse);
    final ledger = GrowthLedger(records);
    expect(ledger.totalFocused, const Duration(minutes: 7));
    expect(ledger.forDay(now).credited, const Duration(minutes: 7));
  });

  test('Reset retains sub-five-minute statistics and starts a distinct focus record', () {
    var now = DateTime(2026, 11, 14, 10);
    final records = <FocusRecord>[];
    final timer = FocusTimer(
      focusLength: const Duration(minutes: 25),
      subjectId: 'math',
      now: () => now,
      onFocusCompleted: () {},
      onFocusRecorded: records.add,
    );
    addTearDown(timer.dispose);
    timer.toggle();
    now = now.add(const Duration(minutes: 3, seconds: 30));
    timer.reset();
    expect(records.single.focused, const Duration(minutes: 3, seconds: 30));
    expect(records.single.growsPlant, isFalse);
    timer.toggle();
    now = now.add(const Duration(minutes: 25));
    timer.refresh();
    expect(records, hasLength(2));
    expect(records.first.id, isNot(records.last.id));
    final ledger = GrowthLedger(records);
    expect(ledger.totalFocused, const Duration(minutes: 28, seconds: 30));
    expect(ledger.forDay(now).credited, const Duration(minutes: 25));
  });

  test('Grace uses actual focus time, capped at one minute, without counting the break', () {
    var now = DateTime(2026, 11, 14, 10);
    final records = <FocusRecord>[];
    var completions = 0;
    final timer = FocusTimer(
      focusLength: const Duration(minutes: 25),
      subjectId: 'math',
      now: () => now,
      onFocusCompleted: () => completions++,
      onFocusRecorded: records.add,
    );
    addTearDown(timer.dispose);
    timer.toggle();
    now = now.add(const Duration(minutes: 23, seconds: 59));
    expect(timer.canFinishWithGrace, isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(timer.canFinishWithGrace, isTrue);
    timer.finishFocus();
    expect(timer.phase, TimerPhase.rest);
    expect(completions, 1);
    expect(records.single.focused, const Duration(minutes: 24));
    expect(records.single.completed, isTrue);
    timer.toggle();
    now = now.add(const Duration(minutes: 8));
    timer.refresh();
    expect(timer.phase, TimerPhase.finished);
    expect(records, hasLength(1));
    expect(timer.focused, const Duration(minutes: 24));
    expect(
      GrowthRules.completionGrace(const Duration(minutes: 10)),
      const Duration(seconds: 30),
    );
    expect(
      GrowthRules.completionGrace(const Duration(minutes: 60)),
      const Duration(minutes: 1),
    );
  });

  test('Process reload retains active intervals and never records backgrounding as interruption', () {
    var now = DateTime(2026, 11, 14, 10);
    final records = <FocusRecord>[];
    final first = FocusTimer(
      focusLength: const Duration(minutes: 25),
      subjectId: 'math',
      now: () => now,
      onFocusCompleted: () {},
      onFocusRecorded: records.add,
    );
    first.toggle();
    now = now.add(const Duration(minutes: 3));
    first.toggle();
    now = now.add(const Duration(hours: 1));
    first.toggle();
    now = now.add(const Duration(minutes: 4));
    final saved = first.toJson();
    first.dispose();
    expect(records, isEmpty);
    now = now.add(const Duration(minutes: 2));
    final restored = FocusTimer.restore(
      saved,
      now: () => now,
      onFocusCompleted: () {},
      onFocusRecorded: records.add,
    );
    addTearDown(restored.dispose);
    restored.refresh();
    expect(restored.isRunning, isTrue);
    expect(restored.focused, const Duration(minutes: 9));
    expect(records, isEmpty);
    restored.finishFocus();
    expect(records.single.subjectId, 'math');
    expect(records.single.focused, const Duration(minutes: 9));
    expect(records.single.legacy, isFalse);
  });

  test('Expired restored focus records only its deadline once, excluding later absence', () {
    var now = DateTime(2026, 11, 14, 10);
    final records = <FocusRecord>[];
    var completed = 0;
    final first = FocusTimer(
      focusLength: const Duration(minutes: 25),
      subjectId: 'math',
      now: () => now,
      onFocusCompleted: () {},
      onFocusRecorded: records.add,
    );
    first.toggle();
    final saved = first.toJson();
    first.dispose();
    now = now.add(const Duration(days: 2));
    final restored = FocusTimer.restore(
      saved,
      now: () => now,
      onFocusCompleted: () => completed++,
      onFocusRecorded: records.add,
    );
    restored.refresh();
    restored.refresh();
    expect(records, hasLength(1));
    expect(records.single.focused, const Duration(minutes: 25));
    expect(records.single.endedAt.toLocal(), DateTime(2026, 11, 14, 10, 25));
    expect(completed, 1);
    final restSnapshot = restored.toJson();
    restored.dispose();
    final rest = FocusTimer.restore(
      restSnapshot,
      now: () => now,
      onFocusCompleted: () => completed++,
      onFocusRecorded: records.add,
    );
    addTearDown(rest.dispose);
    rest.refresh();
    rest.finishFocus();
    expect(records, hasLength(1));
    expect(completed, 1);
  });

  test(
    'Legacy paused timer retains known focus without adding days of downtime',
    () {
      final records = <FocusRecord>[];
      final now = DateTime(2026, 11, 14, 10);
      final timer = FocusTimer.restore(
        {
          'focusMs': 1500000,
          'remainingMs': 840000,
          'phase': 'focus',
          'deadline': null,
        },
        subjectId: 'math',
        now: () => now,
        onFocusCompleted: () {},
        onFocusRecorded: records.add,
      );
      addTearDown(timer.dispose);
      expect(timer.focused, const Duration(minutes: 11));
      timer.finishFocus();
      expect(records.single.focused, const Duration(minutes: 11));
      expect(records.single.legacy, isTrue);
    },
  );
}
