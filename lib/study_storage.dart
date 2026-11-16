import 'growth_rules.dart';

import 'dart:convert';

import 'study_data.dart';
import 'focus_record.dart';
import 'growth_ledger.dart';
import 'study_storage_file.dart'
    if (dart.library.js_interop) 'study_storage_web.dart'
    as platform;

class StudyWorkspace {
  StudyWorkspace({
    List<StudySubject>? subjects,
    List<StudySession>? sessions,
    this.focusCount = 0,
    List<String>? recentSubjects,
    this.activeTimer,
    this.pendingFocusReviewId,
    this.darkMode,
    this.languageCode = 'ar',
    GrowthLedger? growth,
  }) : subjects = subjects ?? [],
       sessions = sessions ?? [],
       growth = growth ?? _legacyGrowth(subjects ?? [], sessions ?? []),
       recentSubjects =
           recentSubjects ?? _completedSubjectHistory(sessions ?? []);

  // Transient import/export metadata. Never duplicated into the study database.
  Map<String, dynamic>? backupCalendars;
  bool backupReplaceCalendars = false;
  final List<StudySubject> subjects;
  final List<StudySession> sessions;
  final GrowthLedger growth;
  Duration targetFor(StudySubject subject) =>
      GrowthRules.targetForEstimates(subject.parts.map((part) => part.minutes));
  PlantGrowth growthFor(
    StudySubject subject,
    DateTime now, {
    bool isFocusing = false,
  }) => growth.forSubject(
    subject.id,
    now: now,
    exam: subject.exam,
    completedTopics: subject.completedCount,
    totalTopics: subject.parts.length,
    isFocusing: isFocusing,
    target: targetFor(subject),
  );
  bool? darkMode;
  String? languageCode;
  int focusCount;
  Map<String, dynamic>? activeTimer;
  String? pendingFocusReviewId;
  final List<String> recentSubjects;
}

class StudyStorage {
  const StudyStorage();

  Future<StudyWorkspace> load() async {
    final raw = await platform.readWorkspace(
      normalize: (raw) => encode(raw == null ? StudyWorkspace() : decode(raw)),
    );
    return raw == null ? StudyWorkspace() : decode(raw);
  }

  StudyWorkspace decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return StudyWorkspace(
      subjects: (json['subjects'] as List)
          .map((subject) => StudySubject.fromJson(subject))
          .toList(),
      sessions: (json['sessions'] as List)
          .map((session) => StudySession.fromJson(session))
          .toList(),
      focusCount: json['focusCount'] as int,
      growth: json['growth'] == null
          ? null
          : GrowthLedger.fromJson(
              Map<String, dynamic>.from(json['growth'] as Map),
            ),
      activeTimer: (json['activeTimer'] as Map?)?.cast<String, dynamic>(),
      pendingFocusReviewId: json['pendingFocusReviewId'] as String?,
      darkMode: json['darkMode'] as bool?,
      languageCode: json.containsKey('languageCode')
          ? (['ar', 'en'].contains(json['languageCode'])
                ? json['languageCode'] as String?
                : null)
          : 'ar',
      recentSubjects: (json['recentSubjects'] as List?)
          ?.cast<String>()
          .toList(),
    );
  }

  String encode(StudyWorkspace workspace) => jsonEncode({
    'subjects': workspace.subjects.map((subject) => subject.toJson()).toList(),
    'sessions': workspace.sessions.map((session) => session.toJson()).toList(),
    'focusCount': workspace.focusCount,
    'growth': workspace.growth.toJson(),
    'activeTimer': workspace.activeTimer,
    'pendingFocusReviewId': workspace.pendingFocusReviewId,
    'darkMode': workspace.darkMode,
    'languageCode': workspace.languageCode,
    'recentSubjects': workspace.recentSubjects,
  });

  Future<void> save(String snapshot) =>
      platform.writeWorkspace(encode(decode(snapshot)));
}

// Old workspaces can recover study history from completed sessions.
List<String> _completedSubjectHistory(List<StudySession> sessions) {
  final completed = sessions.where((session) => session.completed).toList()
    ..sort((a, b) => b.start.compareTo(a.start));
  return completed.map((session) => session.subject).toSet().toList();
}

// Only completed old focus sessions are migrated. Plans and topic completion
// never fabricate focus time. The new field makes migration one-time.
GrowthLedger _legacyGrowth(
  List<StudySubject> subjects,
  List<StudySession> sessions,
) {
  final ids = {for (final subject in subjects) subject.name: subject.id};
  return GrowthLedger([
    for (final (index, session) in sessions.indexed)
      if (session.completed && session.minutes > 0)
        FocusRecord(
          id: 'legacy-focus-$index',
          subjectId: ids[session.subject],
          planned: Duration(minutes: session.minutes),
          endedAt: session.start.add(Duration(minutes: session.minutes)),
          spans: [
            FocusSpan(
              session.start,
              session.start.add(Duration(minutes: session.minutes)),
            ),
          ],
          completed: true,
          legacy: true,
        ),
  ]);
}
