import 'dart:async';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'calendar_data.dart';

class CalendarRepository {
  CalendarRepository({DatabaseFactory? factory, this._path})
    : _factory = factory ?? databaseFactory;
  final DatabaseFactory _factory;
  final String? _path;
  late final Future<Database> database = _open();

  Future<Database> _open() async {
    final path = _path ?? '${await getDatabasesPath()}/istudy-calendars.db';
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE calendars (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, url TEXT NOT NULL UNIQUE, kind INTEGER NOT NULL, '
            'last_sync INTEGER, error TEXT, skipped INTEGER NOT NULL DEFAULT 0, '
            'reminders INTEGER NOT NULL DEFAULT 1)',
          );
          await db.execute(
            'CREATE TABLE events (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'source_id INTEGER NOT NULL REFERENCES calendars(id) ON DELETE CASCADE, '
            'uid TEXT NOT NULL, title TEXT NOT NULL, start TEXT NOT NULL, end TEXT, '
            'description TEXT NOT NULL, location TEXT NOT NULL, date_only INTEGER NOT NULL, '
            'deadline INTEGER NOT NULL, deadline_override INTEGER, remote_done INTEGER NOT NULL, done INTEGER NOT NULL DEFAULT 0, '
            'UNIQUE(source_id, uid))',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE reminders (id INTEGER PRIMARY KEY, signature TEXT NOT NULL, at INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE operation_lock (id INTEGER PRIMARY KEY, owner TEXT NOT NULL, expires INTEGER NOT NULL)',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            final sourceColumns = await db.rawQuery(
              'PRAGMA table_info(calendars)',
            );
            if (!sourceColumns.any((column) => column['name'] == 'reminders')) {
              await db.execute(
                'ALTER TABLE calendars ADD COLUMN reminders INTEGER NOT NULL DEFAULT 1',
              );
            }
            final eventColumns = await db.rawQuery('PRAGMA table_info(events)');
            if (!eventColumns.any(
              (column) => column['name'] == 'deadline_override',
            )) {
              await db.execute(
                'ALTER TABLE events ADD COLUMN deadline_override INTEGER',
              );
            }
          }
        },
      ),
    );
  }

  // The lease serializes foreground and background engines, including notification updates.
  Future<T> withLock<T>(Future<T> Function() operation) async {
    final db = await database;
    final owner =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 31)}';
    var acquired = false;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!acquired && DateTime.now().isBefore(deadline)) {
      acquired = await db.transaction((txn) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await txn.delete(
          'operation_lock',
          where: 'expires <= ?',
          whereArgs: [now],
        );
        await txn.insert('operation_lock', {
          'id': 1,
          'owner': owner,
          'expires': now + 60000,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        final rows = await txn.query('operation_lock', where: 'id = 1');
        return rows.single['owner'] == owner;
      });
      if (!acquired) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    if (!acquired) {
      throw const CalendarImportException(
        'تحديث التقويم جارٍ بالفعل. حاول بعد قليل.',
      );
    }
    final heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      db
          .update(
            'operation_lock',
            {'expires': DateTime.now().millisecondsSinceEpoch + 60000},
            where: 'id = 1 AND owner = ?',
            whereArgs: [owner],
          )
          .catchError((_) => 0);
    });
    try {
      return await operation();
    } finally {
      heartbeat.cancel();
      await db.delete(
        'operation_lock',
        where: 'id = 1 AND owner = ?',
        whereArgs: [owner],
      );
    }
  }

  Future<List<CalendarSource>> sources() async => (await (await database).query(
    'calendars',
    orderBy: 'id',
  )).map(CalendarSource.fromRow).toList();

  Future<List<CalendarItem>> items({bool remindersOnly = false}) async {
    final rows = await (await database).rawQuery(
      'SELECT events.*, calendars.name AS source_name FROM events '
      'JOIN calendars ON calendars.id = events.source_id '
      '${remindersOnly ? 'WHERE calendars.reminders = 1' : ''}',
    );
    return rows.map(CalendarItem.fromRow).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<int> addSource(
    String name,
    String url,
    CalendarKind kind, {
    bool reminders = true,
  }) async => (await database).insert('calendars', {
    'name': name,
    'url': url,
    'kind': kind.index,
    'reminders': reminders ? 1 : 0,
  });

  Future<void> setSourceReminders(int sourceId, bool enabled) async =>
      (await database).update(
        'calendars',
        {'reminders': enabled ? 1 : 0},
        where: 'id = ?',
        whereArgs: [sourceId],
      );
  Future<void> setDeadline(int eventId, bool deadline) async =>
      (await database).update(
        'events',
        {'deadline_override': deadline ? 1 : 0},
        where: 'id = ?',
        whereArgs: [eventId],
      );

  Future<List<CalendarItem>> storePreview(
    int sourceId,
    CalendarPreview preview,
    DateTime now,
  ) async {
    final db = await database;
    final before = {
      for (final item in await items())
        if (item.sourceId == sourceId) item.uid: item,
    };
    final changedIds = <int>[];
    await db.transaction((txn) async {
      final stillPresent = await txn.query(
        'calendars',
        where: 'id = ?',
        whereArgs: [sourceId],
      );
      if (stillPresent.isEmpty) return;
      final incoming = preview.items.map((item) => item.uid).toSet();
      if (preview.skipped == 0) {
        for (final old in before.values) {
          if (!incoming.contains(old.uid)) {
            await txn.delete('events', where: 'id = ?', whereArgs: [old.id]);
          }
        }
      }
      for (final item in preview.items) {
        final old = before[item.uid];
        final row = item.toRow(sourceId);
        if (old == null) {
          changedIds.add(await txn.insert('events', row));
        } else {
          await txn.update('events', row, where: 'id = ?', whereArgs: [old.id]);
          if (old.dateKey != item.dateKey ||
              old.title != item.title ||
              old.end != item.end) {
            changedIds.add(old.id);
          }
        }
      }
      await txn.update(
        'calendars',
        {
          'last_sync': now.millisecondsSinceEpoch,
          'error': null,
          'skipped': preview.skipped,
        },
        where: 'id = ?',
        whereArgs: [sourceId],
      );
    });
    return (await items())
        .where(
          (item) =>
              changedIds.contains(item.id) &&
              !item.completed &&
              !item.isPast(now),
        )
        .toList();
  }

  Future<void> syncError(int sourceId, String message) async =>
      (await database).update(
        'calendars',
        {'error': message},
        where: 'id = ?',
        whereArgs: [sourceId],
      );
  Future<void> removeSource(int sourceId) async => (await database).delete(
    'calendars',
    where: 'id = ?',
    whereArgs: [sourceId],
  );
  Future<void> markDone(int eventId, bool done) async =>
      (await database).update(
        'events',
        {'done': done ? 1 : 0},
        where: 'id = ?',
        whereArgs: [eventId],
      );
  Future<bool> remindersEnabled() async {
    final rows = await (await database).query(
      'settings',
      where: 'key = ?',
      whereArgs: ['reminders'],
    );
    return rows.isNotEmpty && rows.single['value'] == 1;
  }

  Future<void> setRemindersEnabled(bool enabled) async =>
      (await database).insert('settings', {
        'key': 'reminders',
        'value': enabled ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<Map<int, Map<String, Object?>>> reminders() async => {
    for (final row in await (await database).query('reminders'))
      row['id'] as int: row,
  };
  Future<void> rememberReminder(int id, String signature, DateTime at) async =>
      (await database).insert('reminders', {
        'id': id,
        'signature': signature,
        'at': at.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> removeReminder(int id) async =>
      (await database).delete('reminders', where: 'id = ?', whereArgs: [id]);

  Future<Map<String, dynamic>> backupSnapshot() => withLock(
    () async => (await database).transaction(
      (tx) async => {
        'sources': await tx.query('calendars', orderBy: 'id'),
        'events': await tx.query('events', orderBy: 'id'),
        'settings': await tx.query('settings'),
      },
    ),
  );
  static void validateBackup(Map<String, dynamic> data) {
    if (data['sources'] is! List ||
        data['events'] is! List ||
        data['settings'] is! List) {
      throw const FormatException();
    }
    final ids = <int>{}, urls = <String>{};
    for (final raw in data['sources'] as List) {
      final row = Map<String, Object?>.from(raw as Map);
      final source = CalendarSource.fromRow(row);
      final uri = Uri.tryParse(source.url);
      if (source.id < 1 ||
          !ids.add(source.id) ||
          !urls.add(source.url) ||
          source.name.trim().isEmpty ||
          uri == null ||
          !['https', 'webcal'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException();
      }
      for (final key in ['kind', 'skipped', 'reminders']) {
        if (row[key] is! int) throw const FormatException();
      }
      if (![0, 1].contains(row['reminders'])) throw const FormatException();
    }
    final events = <String>{};
    final eventIds = <int>{};
    for (final raw in data['events'] as List) {
      final row = Map<String, Object?>.from(raw as Map);
      final item = CalendarItem.fromRow({...row, 'source_name': ''});
      if (!ids.contains(item.sourceId) ||
          item.id < 1 ||
          !eventIds.add(item.id) ||
          item.uid.isEmpty ||
          !events.add('${item.sourceId}:${item.uid}') ||
          item.title.trim().isEmpty) {
        throw const FormatException();
      }
      for (final key in ['date_only', 'deadline', 'remote_done', 'done']) {
        if (![0, 1].contains(row[key])) throw const FormatException();
      }
      if (row['deadline_override'] != null &&
          ![0, 1].contains(row['deadline_override'])) {
        throw const FormatException();
      }
    }
    final keys = <String>{};
    for (final raw in data['settings'] as List) {
      if (raw is! Map ||
          raw['key'] is! String ||
          !keys.add(raw['key']) ||
          raw['value'] is! int) {
        throw const FormatException();
      }
    }
  }

  // Caller holds withLock while applying the study and calendar snapshots.
  Future<void> restoreBackup(
    Map<String, dynamic> data, {
    required bool replace,
  }) async {
    validateBackup(data);
    await (await database).transaction((tx) async {
      if (replace) {
        await tx.delete('calendars');
        await tx.delete('settings');
      }
      final mapping = <int, int>{};
      for (final raw in data['sources'] as List) {
        final row = Map<String, Object?>.from(raw as Map);
        final oldId = row.remove('id') as int;
        final existing = await tx.query(
          'calendars',
          where: 'url = ?',
          whereArgs: [row['url']],
        );
        if (existing.isNotEmpty) {
          mapping[oldId] = existing.single['id'] as int;
        } else {
          mapping[oldId] = await tx.insert('calendars', {
            for (final key in [
              'name',
              'url',
              'kind',
              'last_sync',
              'error',
              'skipped',
              'reminders',
            ])
              key: row[key],
          });
        }
      }
      for (final raw in data['events'] as List) {
        final row = Map<String, Object?>.from(raw as Map);
        row.remove('id');
        row['source_id'] = mapping[row['source_id']];
        await tx.insert('events', {
          for (final key in [
            'source_id',
            'uid',
            'title',
            'start',
            'end',
            'description',
            'location',
            'date_only',
            'deadline',
            'deadline_override',
            'remote_done',
            'done',
          ])
            key: row[key],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      if (replace) {
        for (final row in data['settings'] as List) {
          await tx.insert('settings', {
            'key': row['key'],
            'value': row['value'],
          });
        }
      }
    });
  }

  Future<void> close() async => (await database).close();
}
