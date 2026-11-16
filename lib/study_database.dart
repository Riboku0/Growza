import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Normalized study tables. Snapshot replacement and first JSON migration are
/// single SQLite transactions, also safe across foreground/background engines.
class StudyDatabase {
  StudyDatabase({DatabaseFactory? factory, required this.path})
    : _factory = factory ?? databaseFactory;
  final DatabaseFactory _factory;
  final String path;
  Future<Database>? _opening;
  Future<Database> get database =>
      _opening ??= _open().catchError((Object error) {
        _opening = null;
        throw error;
      });
  Future<Database> _open() => _factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA busy_timeout = 10000');
      },
      onCreate: (db, version) async {
        for (final sql in [
          'CREATE TABLE workspace_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          'CREATE TABLE subjects (id TEXT PRIMARY KEY, position INTEGER NOT NULL, name TEXT NOT NULL, exam TEXT NOT NULL, pdf_name TEXT, next_part_id INTEGER NOT NULL)',
          'CREATE TABLE topics (subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE, id INTEGER NOT NULL, position INTEGER NOT NULL, title TEXT NOT NULL, minutes INTEGER NOT NULL, priority INTEGER NOT NULL, completed INTEGER NOT NULL, start_page INTEGER, end_page INTEGER, PRIMARY KEY(subject_id,id))',
          'CREATE TABLE study_sessions (position INTEGER PRIMARY KEY, subject TEXT NOT NULL, topic TEXT NOT NULL, start TEXT NOT NULL, minutes INTEGER NOT NULL, part_id INTEGER, completed INTEGER NOT NULL, fixed INTEGER NOT NULL)',
          // No subject foreign key: deleted-subject focus history must survive.
          'CREATE TABLE focus_sessions (id TEXT PRIMARY KEY, subject_id TEXT, position INTEGER NOT NULL, planned_ms INTEGER NOT NULL, ended_at TEXT NOT NULL, completed INTEGER NOT NULL, legacy INTEGER NOT NULL, quality TEXT NOT NULL)',
          'CREATE TABLE focus_spans (record_id TEXT NOT NULL REFERENCES focus_sessions(id) ON DELETE CASCADE, position INTEGER NOT NULL, start TEXT NOT NULL, end TEXT NOT NULL, PRIMARY KEY(record_id,position))',
          'CREATE TABLE study_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        ]) {
          await db.execute(sql);
        }
      },
    ),
  );

  Future<String> readOrMigrate({
    required Future<String?> Function() readLegacy,
    required String Function(String?) normalize,
  }) async => (await database).transaction((tx) async {
    final initialized = await tx.query(
      'workspace_meta',
      where: 'key = ?',
      whereArgs: ['initialized'],
    );
    if (initialized.isEmpty) {
      // Normalize inside the transaction, so generated legacy IDs migrate once.
      final canonical = normalize(await readLegacy());
      await _write(tx, jsonDecode(canonical) as Map<String, dynamic>);
      await tx.insert('workspace_meta', {'key': 'initialized', 'value': '1'});
    }
    return jsonEncode(await _read(tx));
  });

  Future<void> write(String snapshot) async {
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    await (await database).transaction((tx) async {
      await _write(tx, data);
      await tx.insert('workspace_meta', {
        'key': 'initialized',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _write(DatabaseExecutor tx, Map<String, dynamic> data) async {
    final batch = tx.batch();
    for (final table in [
      'focus_spans',
      'focus_sessions',
      'topics',
      'subjects',
      'study_sessions',
      'study_settings',
    ]) {
      batch.delete(table);
    }
    for (final (position, raw) in (data['subjects'] as List).indexed) {
      final s = raw as Map;
      batch.insert('subjects', {
        'id': s['id'],
        'position': position,
        'name': s['name'],
        'exam': s['exam'],
        'pdf_name': s['pdfName'],
        'next_part_id': s['nextPartId'],
      });
      for (final (index, topic) in (s['parts'] as List).indexed) {
        final p = topic as Map;
        batch.insert('topics', {
          'subject_id': s['id'],
          'id': p['id'],
          'position': index,
          'title': p['title'],
          'minutes': p['minutes'],
          'priority': p['priority'] == true ? 1 : 0,
          'completed': p['completed'] == true ? 1 : 0,
          'start_page': p['startPage'],
          'end_page': p['endPage'],
        });
      }
    }
    for (final (position, raw) in (data['sessions'] as List).indexed) {
      final s = raw as Map;
      batch.insert('study_sessions', {
        'position': position,
        'subject': s['subject'],
        'topic': s['topic'],
        'start': s['start'],
        'minutes': s['minutes'],
        'part_id': s['partId'],
        'completed': s['completed'] == true ? 1 : 0,
        'fixed': s['fixed'] == true ? 1 : 0,
      });
    }
    final growth = data['growth'] as Map;
    for (final (position, raw) in (growth['records'] as List).indexed) {
      final r = raw as Map;
      batch.insert('focus_sessions', {
        'id': r['id'],
        'subject_id': r['subjectId'],
        'position': position,
        'planned_ms': r['plannedMs'],
        'ended_at': r['endedAt'],
        'completed': r['completed'] == true ? 1 : 0,
        'legacy': r['legacy'] == true ? 1 : 0,
        'quality': r['quality'] ?? 'full',
      });
      for (final (index, rawSpan) in (r['spans'] as List).indexed) {
        final span = rawSpan as Map;
        batch.insert('focus_spans', {
          'record_id': r['id'],
          'position': index,
          'start': span['start'],
          'end': span['end'],
        });
      }
    }
    for (final entry in data.entries.where(
      (e) => e.key != 'subjects' && e.key != 'sessions' && e.key != 'growth',
    )) {
      batch.insert('study_settings', {
        'key': entry.key,
        'value': jsonEncode(entry.value),
      });
    }
    batch.insert('study_settings', {
      'key': 'growthVersion',
      'value': jsonEncode(growth['version']),
    });
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>> _read(DatabaseExecutor tx) async {
    final settings = await tx.query('study_settings');
    final data = <String, dynamic>{
      for (final row in settings)
        row['key'] as String: jsonDecode(row['value'] as String),
    };
    final topics = await tx.query('topics', orderBy: 'position');
    data['subjects'] = [
      for (final s in await tx.query('subjects', orderBy: 'position'))
        {
          'id': s['id'],
          'name': s['name'],
          'exam': s['exam'],
          'pdfName': s['pdf_name'],
          'nextPartId': s['next_part_id'],
          'parts': [
            for (final p in topics.where((p) => p['subject_id'] == s['id']))
              {
                'id': p['id'],
                'title': p['title'],
                'minutes': p['minutes'],
                'priority': p['priority'] == 1,
                'completed': p['completed'] == 1,
                if (p['start_page'] != null) 'startPage': p['start_page'],
                if (p['end_page'] != null) 'endPage': p['end_page'],
              },
          ],
        },
    ];
    data['sessions'] = [
      for (final s in await tx.query('study_sessions', orderBy: 'position'))
        {
          'subject': s['subject'],
          'topic': s['topic'],
          'start': s['start'],
          'minutes': s['minutes'],
          'partId': s['part_id'],
          'completed': s['completed'] == 1,
          'fixed': s['fixed'] == 1,
        },
    ];
    final spans = await tx.query('focus_spans', orderBy: 'position');
    data['growth'] = {
      'version': data.remove('growthVersion'),
      'records': [
        for (final r in await tx.query('focus_sessions', orderBy: 'position'))
          {
            'id': r['id'],
            'subjectId': r['subject_id'],
            'plannedMs': r['planned_ms'],
            'endedAt': r['ended_at'],
            'completed': r['completed'] == 1,
            'legacy': r['legacy'] == 1,
            'quality': r['quality'],
            'spans': [
              for (final s in spans.where((s) => s['record_id'] == r['id']))
                {'start': s['start'], 'end': s['end']},
            ],
          },
      ],
    };
    return data;
  }

  Future<void> close() async {
    if (_opening != null) {
      await (await _opening!).close();
      _opening = null;
    }
  }
}
