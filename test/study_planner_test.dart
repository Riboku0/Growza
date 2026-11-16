import 'package:flutter_test/flutter_test.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_planner.dart';

void main() {
  final now = DateTime(2026, 11, 10, 14);

  test('repair leaves completed, manual and fixed sessions alone', () {
    final math = StudySubject('Math', dayOffset(now, 1), const [
      StudyPart(1, 'Integration', 40),
      StudyPart(2, 'Derivatives', 20, completed: true),
    ]);
    final physics = StudySubject('Physics', dayOffset(now, 2), const [
      StudyPart(1, 'Mechanics', 35),
      StudyPart(2, 'Practice', 25),
      StudyPart(3, 'Formula review', 15),
    ]);
    final missed = StudySession(
      'Math',
      'Integration',
      atTime(now, 12),
      40,
      partId: 1,
    );
    final completed = StudySession(
      'Math',
      'Derivatives',
      atTime(now, 10),
      20,
      partId: 2,
      completed: true,
    );
    final manual = StudySession('General study', 'مراجعة', now, 10);
    final fixed = StudySession(
      'Physics',
      'Formula review',
      atTime(now, 16),
      15,
      partId: 3,
      fixed: true,
    );
    final outsideWindow = StudySession(
      'Physics',
      'Mechanics',
      atTime(now, 19),
      35,
      partId: 1,
    );
    final plan = StudyPlan.fit(
      tasks: pendingTasks([physics, math]),
      sessions: [missed, completed, manual, fixed, outsideWindow],
      now: now,
      start: now,
      end: atTime(now, 15, 15),
    );

    expect(plan.kept, [completed, manual, fixed, outsideWindow]);
    expect(plan.replaced.values, [missed]);
    expect(plan.scheduled.single.start, atTime(now, 14, 15));
    expect(plan.scheduled.single.topic, 'Integration');
    expect(plan.unscheduled.single.part.title, 'Practice');
    expect(plan.unscheduledMinutes, 25);
  });

  test(
    'earlier exams and priorities get first choice without crossing exam day',
    () {
      final exam = dayOffset(now, 1);
      final math = StudySubject('Math', exam, const [
        StudyPart(1, 'مراجعة', 25),
        StudyPart(2, 'Integration', 25, priority: true),
      ]);
      final physics = StudySubject('Physics', dayOffset(now, 2), const [
        StudyPart(1, 'Mechanics', 35, priority: true),
      ]);
      final plan = StudyPlan.fit(
        tasks: pendingTasks([physics, math]),
        sessions: [],
        now: now,
        start: atTime(now, 23, 30),
        end: atTime(exam, 0, 40),
      );

      expect(plan.scheduled.map((session) => session.topic), [
        'Integration',
        'Mechanics',
      ]);
      expect(plan.scheduled[1].start, exam);
      expect(plan.unscheduled.single.part.title, 'مراجعة');
    },
  );
}
