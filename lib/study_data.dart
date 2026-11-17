import 'app_strings.dart';

import 'package:flutter/material.dart';

import 'focus_timer.dart';
import 'local_id.dart';

class StudySubject {
  StudySubject(
    this.name,
    this.exam,
    this.parts, {
    this.pdfName,
    String? id,
    int? nextPartId,
  }) : id = id ?? newLocalId('subject'),
       _nextPartId = nextPartId ?? 1;

  final String id;
  final String name;
  final DateTime? exam;
  final List<StudyPart> parts;
  final String? pdfName;
  final int _nextPartId;
  int get nextPartId => parts.fold<int>(
    _nextPartId,
    (next, part) => part.id >= next ? part.id + 1 : next,
  );

  int get completedCount => parts.where((part) => part.completed).length;
  StudyPart? get nextPart => parts.where((part) => !part.completed).firstOrNull;
  StudySubject withParts(List<StudyPart> parts) => StudySubject(
    name,
    exam,
    parts,
    id: id,
    pdfName: pdfName,
    nextPartId: nextPartId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'exam': exam?.toIso8601String(),
    'pdfName': pdfName,
    'nextPartId': nextPartId,
    'parts': parts.map((part) => part.toJson()).toList(),
  };

  factory StudySubject.fromJson(Map<String, dynamic> json) => StudySubject(
    json['name'] as String,
    json['exam'] == null ? null : DateTime.parse(json['exam'] as String),
    (json['parts'] as List)
        .map(
          (part) => StudyPart.fromJson({
            ...Map<String, dynamic>.from(part as Map),
            if (part['pdfName'] == null &&
                part['startPage'] != null &&
                json['pdfName'] != null)
              'pdfName': json['pdfName'],
          }),
        )
        .toList(),
    pdfName: json['pdfName'] as String?,
    id: json['id'] as String?,
    nextPartId: json['nextPartId'] as int?,
  );
}

class StudyPart {
  const StudyPart(
    this.id,
    this.title,
    this.minutes, {
    this.priority = false,
    this.completed = false,
    this.startPage,
    this.endPage,
    this.pdfName,
  });

  final int id;
  final String title;
  final int minutes;
  final bool priority;
  final bool completed;
  final int? startPage, endPage;
  final String? pdfName;

  StudyPart withPdfReference(String? name) => StudyPart(
    id,
    title,
    minutes,
    priority: priority,
    completed: completed,
    startPage: startPage,
    endPage: endPage,
    pdfName: name,
  );

  StudyPart markComplete() => StudyPart(
    id,
    title,
    minutes,
    priority: priority,
    completed: true,
    startPage: startPage,
    endPage: endPage,
    pdfName: pdfName,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'priority': priority,
    'completed': completed,
    'startPage': ?startPage,
    'endPage': ?endPage,
    'pdfName': ?pdfName,
  };

  factory StudyPart.fromJson(Map<String, dynamic> json) => StudyPart(
    json['id'] as int,
    json['title'] as String,
    json['minutes'] as int,
    priority: json['priority'] as bool,
    completed: json['completed'] as bool,
    startPage: json['startPage'] as int?,
    endPage: json['endPage'] as int?,
    pdfName: json['pdfName'] as String?,
  );
}

typedef StudyTask = ({StudySubject subject, StudyPart part});
typedef PartKey = ({String subject, int id});
typedef StudyBlock = ({DateTime start, DateTime end});

extension StudyTaskKey on StudyTask {
  PartKey get key => (subject: subject.name, id: part.id);
}

class StudySession {
  const StudySession(
    this.subject,
    this.topic,
    this.start,
    this.minutes, {
    this.partId,
    this.completed = false,
    this.fixed = false,
  });

  final String subject;
  final String topic;
  final DateTime start;
  final int minutes;
  final int? partId;
  final bool completed;
  final bool fixed;

  PartKey? get partKey =>
      partId == null ? null : (subject: subject, id: partId!);

  DateTime get endWithBreak =>
      start.add(Duration(minutes: minutes) + studyBreak);

  bool overlaps(StudySession other) =>
      start.isBefore(other.endWithBreak) && other.start.isBefore(endWithBreak);

  StudySession copyWith({
    String? subject,
    String? topic,
    bool? completed,
    bool? fixed,
  }) => StudySession(
    subject ?? this.subject,
    topic ?? this.topic,
    start,
    minutes,
    partId: partId,
    completed: completed ?? this.completed,
    fixed: fixed ?? this.fixed,
  );

  Map<String, Object?> toJson() => {
    'subject': subject,
    'topic': topic,
    'start': start.toIso8601String(),
    'minutes': minutes,
    'partId': partId,
    'completed': completed,
    'fixed': fixed,
  };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    json['subject'] as String,
    json['topic'] as String,
    DateTime.parse(json['start'] as String),
    json['minutes'] as int,
    partId: json['partId'] as int?,
    completed: json['completed'] as bool,
    fixed: json['fixed'] as bool? ?? false,
  );
}

DateTime dayOffset(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime atTime(DateTime date, int hour, [int minute = 0]) =>
    DateTime(date.year, date.month, date.day, hour, minute);

String clockLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String examLabel(BuildContext context, DateTime? exam) {
  if (exam == null) return tr(context, "بلا موعد اختبار");
  final date = MaterialLocalizations.of(context).formatShortMonthDay(exam);
  return exam == DateUtils.dateOnly(exam)
      ? date
      : tr(context, '{0} الساعة {1}', [date, clockLabel(exam)]);
}

String dayLabel(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  const weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  final shortDay = tr(context, weekdays[date.weekday - 1]);
  return '$shortDay ${localizations.formatShortMonthDay(date)}';
}

String subjectLabel(String name, {BuildContext? context}) =>
    name == 'General study'
    ? (context == null ? 'مذاكرة عامة' : tr(context, 'مذاكرة عامة'))
    : name;

// Undated subjects follow dated subjects without inventing a deadline.
int compareExamDates(DateTime? a, DateTime? b) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
