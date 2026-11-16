import 'package:flutter/material.dart';

import 'calendar_data.dart';
import 'study_data.dart';

List<CalendarItem> examCalendarItems(
  List<StudySubject> subjects, {
  String languageCode = 'ar',
}) {
  final sorted = [...subjects]..sort((a, b) => a.name.compareTo(b.name));
  final used = <int>{};
  return [for (final subject in sorted) _examItem(subject, used, languageCode)];
}

CalendarItem _examItem(
  StudySubject subject,
  Set<int> used,
  String languageCode,
) {
  var hash = 2166136261;
  for (final unit in subject.name.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0x1fffffff;
  }
  var id = -(hash + 1);
  while (!used.add(id)) {
    id = id == -536870912 ? -1 : id - 1;
  }
  return CalendarItem(
    id: id,
    sourceId: -1,
    sourceName: languageCode == 'en' ? 'Your exams' : 'اختباراتك',
    uid: 'exam:${subject.name}',
    title: languageCode == 'en'
        ? 'Exam · ${subject.name}'
        : 'اختبار · ${subject.name}',
    start: subject.exam,
    dateOnly: subject.exam == DateUtils.dateOnly(subject.exam),
  );
}
