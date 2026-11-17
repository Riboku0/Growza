import 'calendar_repository.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'study_data.dart';
import 'study_storage.dart';
import 'focus_timer.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
}

class WorkspaceBackup {
  static const version = 1;
  static const maxBytes = 10 * 1024 * 1024;
  static String export(StudyWorkspace workspace, {DateTime? now}) =>
      jsonEncode({
        'app': 'Growza',
        'version': version,
        'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
        if (workspace.backupCalendars != null)
          'calendars': workspace.backupCalendars,
        'workspace': jsonDecode(const StudyStorage().encode(workspace)),
      });
  static StudyWorkspace parse(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const BackupException('حجم النسخة الاحتياطية أكبر من المسموح.');
    }
    try {
      final envelope = jsonDecode(text);
      if (envelope is! Map ||
          envelope['app'] != 'Growza' ||
          envelope['version'] != version ||
          envelope['workspace'] is! Map) {
        throw const FormatException();
      }
      final map = Map<String, dynamic>.from(envelope['workspace'] as Map);
      if (map['subjects'] is! List ||
          map['sessions'] is! List ||
          map['focusCount'] is! int ||
          map['focusCount'] < 0) {
        throw const FormatException();
      }
      final ids = <String>{}, names = <String>{};
      for (final s in map['subjects'] as List) {
        if (s is! Map ||
            s['id'] is! String ||
            (s['id'] as String).isEmpty ||
            !ids.add(s['id']) ||
            s['name'] is! String ||
            (s['name'] as String).trim().isEmpty ||
            !names.add((s['name'] as String).toLowerCase())) {
          throw const FormatException();
        }
        final parts = <int>{};
        for (final p in s['parts'] as List) {
          if ((p['startPage'] != null || p['endPage'] != null) &&
              (p['startPage'] is! int ||
                  p['endPage'] is! int ||
                  p['startPage'] < 1 ||
                  p['endPage'] < p['startPage'])) {
            throw const FormatException();
          }
          if (p['pdfName'] != null && p['pdfName'] is! String) {
            throw const FormatException();
          }
          if (p['id'] is! int ||
              p['id'] <= 0 ||
              !parts.add(p['id']) ||
              p['minutes'] is! int ||
              p['minutes'] < 1 ||
              p['minutes'] > 720 ||
              p['title'] is! String ||
              (p['title'] as String).trim().isEmpty) {
            throw const FormatException();
          }
        }
      }
      final records = <String>{};
      for (final r in (map['growth'] as Map)['records'] as List) {
        if (r['id'] is! String || !records.add(r['id'])) {
          throw const FormatException();
        }
      }
      final result = const StudyStorage().decode(jsonEncode(map));
      for (final s in result.sessions) {
        if (s.minutes < 1 || s.minutes > 720 || s.topic.trim().isEmpty) {
          throw const FormatException();
        }
      }
      if (result.pendingFocusReviewId != null &&
          !records.contains(result.pendingFocusReviewId)) {
        throw const FormatException();
      }
      if (result.activeTimer case final active?) {
        if (active['session'] != null) {
          StudySession.fromJson(
            Map<String, dynamic>.from(active['session'] as Map),
          );
        }
        final timer = FocusTimer.restore(
          Map<String, dynamic>.from(active['timer'] as Map),
          onFocusCompleted: () {},
        );
        timer.dispose();
      }
      if (envelope['calendars'] != null) {
        result.backupCalendars = Map<String, dynamic>.from(
          envelope['calendars'] as Map,
        );
        CalendarRepository.validateBackup(result.backupCalendars!);
      }
      return result;
    } catch (error) {
      if (error is BackupException) rethrow;
      throw const BackupException(
        'هذا الملف ليس نسخة Growza صالحة أو أن إصداره غير مدعوم.',
      );
    }
  }

  static StudyWorkspace merge(StudyWorkspace current, StudyWorkspace incoming) {
    // Clone first: previews and failed imports never mutate the current workspace.
    final storage = const StudyStorage();
    final result = storage.decode(storage.encode(current));
    final names = <String, String>{};
    for (final subject in incoming.subjects) {
      final index = result.subjects.indexWhere((s) => s.id == subject.id);
      if (index >= 0) {
        final old = result.subjects[index];
        names[subject.name] = old.name;
        final parts = [...old.parts];
        for (final p in subject.parts) {
          if (!parts.any((x) => x.id == p.id)) parts.add(p);
        }
        result.subjects[index] = StudySubject(
          old.name,
          old.exam,
          parts,
          id: old.id,
          pdfName: old.pdfName,
          nextPartId: math.max(old.nextPartId, subject.nextPartId),
        );
      } else {
        var name = subject.name;
        var suffix = 2;
        while (result.subjects.any(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
        )) {
          name = '${subject.name} ($suffix)';
          suffix++;
        }
        names[subject.name] = name;
        result.subjects.add(
          StudySubject(
            name,
            subject.exam,
            subject.parts,
            id: subject.id,
            pdfName: subject.pdfName,
            nextPartId: subject.nextPartId,
          ),
        );
      }
    }
    final existing = {for (final r in result.growth.records) r.id: r};
    for (final r in incoming.growth.records) {
      final old = existing[r.id];
      if (old != null) {
        final a = old.toJson()..remove('quality');
        final b = r.toJson()..remove('quality');
        if (jsonEncode(a) != jsonEncode(b)) {
          throw const BackupException(
            'توجد سجلات تركيز متعارضة. لم تتغير بياناتك؛ استخدم ملفاً آخر أو اختر الاستبدال.',
          );
        }
      } else {
        result.growth.add(r);
      }
    }
    String key(StudySession s) => jsonEncode([
      s.subject,
      s.topic,
      s.start.toIso8601String(),
      s.minutes,
      s.partId,
    ]);
    final keys = result.sessions.map(key).toSet();
    for (final s in incoming.sessions) {
      final adjusted = s.copyWith(subject: names[s.subject] ?? s.subject);
      if (keys.add(key(adjusted))) result.sessions.add(adjusted);
    }
    result.focusCount = math.max(
      math.max(result.focusCount, incoming.focusCount),
      result.growth.records.where((r) => r.completed).length,
    );
    for (final name in incoming.recentSubjects) {
      final mapped = names[name] ?? name;
      if (!result.recentSubjects.contains(mapped)) {
        result.recentSubjects.add(mapped);
      }
    }
    result.backupCalendars = incoming.backupCalendars;
    // Current settings, timer and pending review win in a merge.
    return result;
  }
}
