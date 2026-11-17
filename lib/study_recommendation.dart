import 'package:flutter/material.dart';

import 'study_data.dart';

/// Prefer a real upcoming exam; otherwise resume unfinished undated work.
StudySubject? recommendSubject(
  List<StudySubject> subjects,
  List<String> recent,
  DateTime now,
) {
  final upcoming =
      subjects
          .where(
            (s) =>
                s.nextPart != null &&
                s.exam != null &&
                !DateUtils.dateOnly(s.exam!).isBefore(DateUtils.dateOnly(now)),
          )
          .toList()
        ..sort((a, b) {
          final date = compareExamDates(a.exam, b.exam);
          if (date != 0) return date;
          final count = (b.parts.length - b.completedCount).compareTo(
            a.parts.length - a.completedCount,
          );
          return count != 0
              ? count
              : subjects.indexOf(a).compareTo(subjects.indexOf(b));
        });
  if (upcoming.isNotEmpty) return upcoming.first;
  final undated = subjects
      .where((s) => s.exam == null && s.nextPart != null)
      .toList();
  for (final name in recent) {
    final subject = undated.where((s) => s.name == name).firstOrNull;
    if (subject != null) return subject;
  }
  if (undated.isNotEmpty) return undated.first;
  for (final name in recent) {
    final subject = subjects.where((s) => s.name == name).firstOrNull;
    if (subject != null) return subject;
  }
  return subjects.firstOrNull;
}
