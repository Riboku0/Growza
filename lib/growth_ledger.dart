import 'focus_record.dart';
import 'growth_rules.dart';

DateTime _day(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

typedef _Slice = ({
  FocusRecord record,
  DateTime day,
  DateTime start,
  Duration duration,
});

Iterable<_Slice> _slices(FocusRecord record) sync* {
  for (final span in record.spans) {
    var cursor = span.start.toLocal();
    final end = span.end.toLocal();
    while (cursor.isBefore(end)) {
      final day = _day(cursor);
      final midnight = DateTime(day.year, day.month, day.day + 1);
      final until = end.isBefore(midnight) ? end : midnight;
      yield (
        record: record,
        day: day,
        start: cursor,
        duration: until.difference(cursor),
      );
      cursor = until;
    }
  }
}

class DailyGrowth {
  const DailyGrowth(this.focused, this.credited, {Duration? budgetUsed})
    : budgetUsed = budgetUsed ?? credited;
  final Duration budgetUsed;
  final Duration focused;
  final Duration credited;
  Duration get remaining => GrowthRules.dailyGrowthLimit - budgetUsed;
  bool get limitReached => budgetUsed >= GrowthRules.dailyGrowthLimit;
  String? get message => limitReached ? GrowthRules.dailyLimitMessage : null;
}

class PlantGrowth {
  const PlantGrowth({
    required this.focused,
    required this.credited,
    required this.topicProgress,
    required this.lastFocusedAt,
    required this.harvested,
    required this.resting,
    this.target = GrowthRules.fallbackTarget,
  });
  final Duration focused;
  final Duration credited;
  final double topicProgress;
  final DateTime? lastFocusedAt;
  final bool harvested;
  final bool resting;
  final Duration target;
  double get visualUnits => stage == PlantStage.tree
      ? stage.index.toDouble()
      : stage.index + stageProgress;
  PlantStage get stage => GrowthRules.stageFor(credited, target: target);
  double get stageProgress =>
      GrowthRules.progressWithinStage(credited, target: target);
}

class GrowthLedger {
  GrowthLedger([Iterable<FocusRecord> records = const []]) {
    for (final record in records) {
      add(record);
    }
  }
  final _records = <String, FocusRecord>{};
  List<FocusRecord> get records => List.unmodifiable(_records.values);

  // Reopening the same completed timer must never award its minutes twice.
  bool add(FocusRecord record) {
    if (_records.containsKey(record.id)) return false;
    _records[record.id] = record;
    return true;
  }

  // Review changes the reward of this record in place, never its identity/time.
  bool setQuality(String recordId, FocusQuality quality) {
    final record = _records[recordId];
    if (record == null) return false;
    _records[recordId] = record.withQuality(quality);
    return true;
  }

  int currentStreak(DateTime now) {
    final focused = <DateTime, Duration>{};
    for (final record in records) {
      for (final slice in _slices(record)) {
        focused[slice.day] =
            (focused[slice.day] ?? Duration.zero) + slice.duration;
      }
    }
    var cursor = _day(now);
    // Today can still continue yesterday's streak until the day is over.
    if ((focused[cursor] ?? Duration.zero) < GrowthRules.minimumGrowthSession) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var streak = 0;
    while ((focused[cursor] ?? Duration.zero) >=
        GrowthRules.minimumGrowthSession) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  Duration get totalFocused => _records.values.fold(
    Duration.zero,
    (total, record) => total + record.focused,
  );

  List<({String subjectId, DateTime day, Duration duration, Duration budget})>
  _credits() {
    final slices =
        [
          for (final record in _records.values)
            if (record.growsPlant) ..._slices(record),
        ]..sort((a, b) {
          final time = a.start.compareTo(b.start);
          return time != 0 ? time : a.record.id.compareTo(b.record.id);
        });
    final used = <DateTime, Duration>{};
    final result =
        <
          ({String subjectId, DateTime day, Duration duration, Duration budget})
        >[];
    for (final slice in slices) {
      final remaining =
          GrowthRules.dailyGrowthLimit - (used[slice.day] ?? Duration.zero);
      if (remaining <= Duration.zero) continue;
      final amount = slice.duration < remaining ? slice.duration : remaining;
      used[slice.day] = (used[slice.day] ?? Duration.zero) + amount;
      result.add((
        subjectId: slice.record.subjectId!,
        day: slice.day,
        duration: GrowthRules.qualityCredit(amount, slice.record.quality),
        budget: amount,
      ));
    }
    return result;
  }

  DailyGrowth forDay(DateTime date) {
    final day = _day(date);
    final focused = [for (final record in _records.values) ..._slices(record)]
        .where((slice) => slice.day == day)
        .fold(Duration.zero, (total, slice) => total + slice.duration);
    final credits = _credits().where((slice) => slice.day == day).toList();
    final credited = credits.fold(
      Duration.zero,
      (total, slice) => total + slice.duration,
    );
    final budgetUsed = credits.fold(
      Duration.zero,
      (total, slice) => total + slice.budget,
    );
    return DailyGrowth(focused, credited, budgetUsed: budgetUsed);
  }

  PlantGrowth forSubject(
    String subjectId, {
    required DateTime now,
    required DateTime exam,
    required int completedTopics,
    required int totalTopics,
    bool isFocusing = false,
    Duration target = GrowthRules.fallbackTarget,
  }) {
    if (target <= Duration.zero) {
      throw ArgumentError.value(target, 'target', 'Must be positive');
    }
    final subjectRecords = _records.values.where(
      (record) => record.subjectId == subjectId,
    );
    final focused = subjectRecords.fold(
      Duration.zero,
      (total, record) => total + record.focused,
    );
    final credited = _credits()
        .where((slice) => slice.subjectId == subjectId)
        .fold(Duration.zero, (total, slice) => total + slice.duration);
    DateTime? last;
    for (final record in subjectRecords) {
      for (final span in record.spans) {
        if (last == null || span.end.isAfter(last)) last = span.end;
      }
    }
    final localExam = exam.toLocal();
    final cutoff = localExam == _day(localExam)
        ? DateTime(localExam.year, localExam.month, localExam.day + 1)
        : localExam;
    return PlantGrowth(
      focused: focused,
      target: target,
      credited: credited,
      topicProgress: totalTopics <= 0
          ? 0
          : (completedTopics / totalTopics).clamp(0.0, 1.0),
      lastFocusedAt: last,
      harvested: !cutoff.isAfter(now),
      resting: !isFocusing && last != null && _day(last).isBefore(_day(now)),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'records': records.map((record) => record.toJson()).toList(),
  };
  factory GrowthLedger.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported growth history version.');
    }
    return GrowthLedger(
      (json['records'] as List).map(
        (record) =>
            FocusRecord.fromJson(Map<String, dynamic>.from(record as Map)),
      ),
    );
  }
}
