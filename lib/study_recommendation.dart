import 'package:flutter/material.dart';

import 'study_data.dart';

/// A deterministic suggestion from dates and unfinished topics, never a
/// guessed difficulty. Manual choice and a running timer take precedence in UI.
StudySubject? recommendSubject(
  List<StudySubject> subjects,
  List<String> recent,
  DateTime now,
) {
  final eligible =
      subjects
          .where(
            (s) =>
                s.nextPart != null &&
                !DateUtils.dateOnly(s.exam).isBefore(DateUtils.dateOnly(now)),
          )
          .toList()
        ..sort((a, b) {
          final date = a.exam.compareTo(b.exam);
          if (date != 0) return date;
          final leftA = a.parts.length - a.completedCount;
          final leftB = b.parts.length - b.completedCount;
          final count = leftB.compareTo(leftA);
          return count != 0
              ? count
              : subjects.indexOf(a).compareTo(subjects.indexOf(b));
        });
  if (eligible.isNotEmpty) return eligible.first;
  for (final name in recent) {
    final subject = subjects.where((s) => s.name == name).firstOrNull;
    if (subject != null) return subject;
  }
  return subjects.firstOrNull;
}
