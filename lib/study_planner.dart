import 'focus_timer.dart';
import 'study_data.dart';

List<StudyTask> pendingTasks(List<StudySubject> subjects) {
  final tasks = [
    for (final subject in subjects)
      for (final part in subject.parts)
        if (!part.completed) (subject: subject, part: part),
  ];
  return tasks..sort((a, b) {
    final exam = a.subject.exam.compareTo(b.subject.exam);
    if (exam != 0) return exam;
    if (a.part.priority != b.part.priority) return a.part.priority ? -1 : 1;
    final subject = a.subject.name.compareTo(b.subject.name);
    return subject == 0 ? a.part.id.compareTo(b.part.id) : subject;
  });
}

class StudyPlan {
  StudyPlan({
    required this.kept,
    required this.replaced,
    required this.scheduled,
    required this.unscheduled,
  });

  final List<StudySession> kept;
  final Map<PartKey, StudySession> replaced;
  final List<StudySession> scheduled;
  final List<StudyTask> unscheduled;

  int get unscheduledMinutes =>
      unscheduled.fold(0, (sum, task) => sum + task.part.minutes);

  bool get hasChanges => scheduled.isNotEmpty || replaced.isNotEmpty;

  static StudyPlan fit({
    required List<StudyTask> tasks,
    required List<StudySession> sessions,
    required DateTime now,
    required DateTime start,
    required DateTime end,
    List<StudyBlock> blocked = const [],
  }) {
    final pending = tasks.map((task) => task.key).toSet();
    final kept = <StudySession>[];
    final placed = <PartKey>{};
    final replaced = <PartKey, StudySession>{};
    for (final session in sessions) {
      final key = session.partKey;
      final overlapsWindow =
          session.start.isBefore(end) && start.isBefore(session.endWithBreak);
      if (key != null &&
          pending.contains(key) &&
          !session.fixed &&
          !session.completed &&
          (!session.endWithBreak.isAfter(now) || overlapsWindow)) {
        replaced[key] = session;
      } else {
        kept.add(session);
        if (key != null && !session.completed) placed.add(key);
      }
    }

    final busy = <StudyBlock>[
      for (final session in kept)
        (start: session.start, end: session.endWithBreak),
      ...blocked,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final scheduled = <StudySession>[];
    final unscheduled = <StudyTask>[];
    for (final task in tasks) {
      if (placed.contains(task.key)) continue;
      final exam = task.subject.exam;
      final limit = exam.isBefore(end) ? exam : end;
      final duration = Duration(minutes: task.part.minutes) + studyBreak;
      var slot = start;
      for (final block in busy) {
        if (!block.end.isAfter(slot)) continue;
        if (!slot.add(duration).isAfter(block.start)) break;
        slot = block.end;
      }
      if (slot.add(duration).isAfter(limit)) {
        unscheduled.add(task);
        continue;
      }
      final session = StudySession(
        task.subject.name,
        task.part.title,
        slot,
        task.part.minutes,
        partId: task.part.id,
      );
      scheduled.add(session);
      busy.add((start: session.start, end: session.endWithBreak));
      busy.sort((a, b) => a.start.compareTo(b.start));
    }
    return StudyPlan(
      kept: kept,
      replaced: replaced,
      scheduled: scheduled..sort((a, b) => a.start.compareTo(b.start)),
      unscheduled: unscheduled,
    );
  }
}
