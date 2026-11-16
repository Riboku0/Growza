enum CalendarKind { deadlines, classes, mixed }

class CalendarSource {
  const CalendarSource({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
    this.lastSync,
    this.error,
    this.skipped = 0,
    this.reminders = true,
  });
  final int id;
  final String name;
  final String url;
  final CalendarKind kind;
  final DateTime? lastSync;
  final String? error;
  final int skipped;
  final bool reminders;
  factory CalendarSource.fromRow(Map<String, Object?> row) => CalendarSource(
    id: row['id'] as int,
    name: row['name'] as String,
    url: row['url'] as String,
    kind: CalendarKind.values[row['kind'] as int],
    lastSync: row['last_sync'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['last_sync'] as int),
    error: row['error'] as String?,
    skipped: row['skipped'] as int,
    reminders: row['reminders'] == 1,
  );
}

class CalendarItem {
  const CalendarItem({
    this.id = 0,
    this.sourceId = 0,
    this.sourceName = '',
    required this.uid,
    required this.title,
    required this.start,
    this.end,
    this.description = '',
    this.location = '',
    this.dateOnly = false,
    this.deadline = true,
    this.remoteDone = false,
    this.done = false,
  });
  final int id;
  final int sourceId;
  final String sourceName;
  final String uid;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String description;
  final String location;
  final bool dateOnly;
  final bool deadline;
  final bool remoteDone;
  final bool done;
  bool get completed => remoteDone || done;

  // Imported dates close locally once their final calendar day has passed.
  // An all-day event's end is exclusive, so midnight belongs to the prior day.
  bool dayHasPassed(DateTime now) {
    if (sourceId == -1) return false;
    final finish = !deadline && end != null ? end!.toLocal() : null;
    final eventDay = finish == null
        ? start.toLocal()
        : finish == DateTime(finish.year, finish.month, finish.day)
        ? finish.subtract(const Duration(microseconds: 1))
        : finish;
    final cutoff = DateTime(eventDay.year, eventDay.month, eventDay.day + 1);
    return !cutoff.isAfter(now);
  }

  bool completedAt(DateTime now) => completed || dayHasPassed(now);
  bool isPast(DateTime now) => dateOnly
      ? !DateTime(start.year, start.month, start.day + 1).isAfter(now)
      : (deadline ? start : end ?? start).isBefore(now);
  String get dateKey => dateOnly
      ? '${start.year}-${start.month}-${start.day}'
      : start.toUtc().toIso8601String();
  Map<String, Object?> toRow(int calendarId) => {
    'source_id': calendarId,
    'uid': uid,
    'title': title,
    'start': dateOnly
        ? '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}'
        : start.toUtc().toIso8601String(),
    'end': end?.toUtc().toIso8601String(),
    'description': description,
    'location': location,
    'date_only': dateOnly ? 1 : 0,
    'deadline': deadline ? 1 : 0,
    'remote_done': remoteDone ? 1 : 0,
  };
  factory CalendarItem.fromRow(Map<String, Object?> row) => CalendarItem(
    id: row['id'] as int,
    sourceId: row['source_id'] as int,
    sourceName: row['source_name'] as String,
    uid: row['uid'] as String,
    title: row['title'] as String,
    start: DateTime.parse(row['start'] as String).toLocal(),
    end: row['end'] == null
        ? null
        : DateTime.parse(row['end'] as String).toLocal(),
    description: row['description'] as String,
    location: row['location'] as String,
    dateOnly: row['date_only'] == 1,
    deadline: (row['deadline_override'] ?? row['deadline']) == 1,
    remoteDone: row['remote_done'] == 1,
    done: row['done'] == 1,
  );
}

class CalendarPreview {
  const CalendarPreview(this.name, this.items, {this.skipped = 0});
  final String name;
  final List<CalendarItem> items;
  final int skipped;
}

class CalendarImportException implements Exception {
  const CalendarImportException(this.message);
  final String message;
  @override
  String toString() => message;
}
