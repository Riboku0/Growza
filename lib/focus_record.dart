import 'growth_rules.dart';

class FocusSpan {
  FocusSpan(this.start, this.end) {
    if (!end.isAfter(start)) {
      throw ArgumentError('Focus span must have a positive duration.');
    }
  }
  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);

  Map<String, dynamic> toJson() => {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
  };
  factory FocusSpan.fromJson(Map<String, dynamic> json) => FocusSpan(
    DateTime.parse(json['start'] as String),
    DateTime.parse(json['end'] as String),
  );
}

class FocusRecord {
  FocusRecord({
    required this.id,
    required this.subjectId,
    required this.planned,
    required this.endedAt,
    required List<FocusSpan> spans,
    required this.completed,
    this.legacy = false,
    this.quality = FocusQuality.full,
  }) : spans = List.unmodifiable(spans) {
    if (id.isEmpty || planned <= Duration.zero) {
      throw ArgumentError('Invalid focus record.');
    }
    DateTime? previousEnd;
    for (final span in spans) {
      if (previousEnd != null && span.start.isBefore(previousEnd)) {
        throw ArgumentError('Focus spans must not overlap.');
      }
      if (span.end.isAfter(endedAt)) {
        throw ArgumentError('Focus span ends after the record.');
      }
      previousEnd = span.end;
    }
    if (focused > planned) {
      throw ArgumentError('Focused duration exceeds the planned session.');
    }
  }
  final String id;
  final String? subjectId;
  final Duration planned;
  final DateTime endedAt;
  final List<FocusSpan> spans;
  final bool completed;
  // Earlier versions stored the planned duration and scheduled start only.
  final bool legacy;
  final FocusQuality quality;
  FocusRecord withQuality(FocusQuality value) => FocusRecord(
    id: id,
    subjectId: subjectId,
    planned: planned,
    endedAt: endedAt,
    spans: spans,
    completed: completed,
    legacy: legacy,
    quality: value,
  );
  Duration get focused =>
      spans.fold(Duration.zero, (total, span) => total + span.duration);
  bool get growsPlant =>
      subjectId != null && focused >= GrowthRules.minimumGrowthSession;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'plannedMs': planned.inMilliseconds,
    'endedAt': endedAt.toUtc().toIso8601String(),
    'spans': spans.map((span) => span.toJson()).toList(),
    'completed': completed,
    'legacy': legacy,
    'quality': quality.name,
  };
  factory FocusRecord.fromJson(Map<String, dynamic> json) => FocusRecord(
    id: json['id'] as String,
    subjectId: json['subjectId'] as String?,
    planned: Duration(milliseconds: json['plannedMs'] as int),
    endedAt: DateTime.parse(json['endedAt'] as String),
    spans: (json['spans'] as List)
        .map(
          (span) => FocusSpan.fromJson(Map<String, dynamic>.from(span as Map)),
        )
        .toList(),
    completed: json['completed'] as bool,
    legacy: json['legacy'] as bool? ?? false,
    quality: FocusQuality.values.firstWhere(
      (quality) => quality.name == (json['quality'] ?? 'full'),
      orElse: () => throw const FormatException('Unknown focus quality.'),
    ),
  );
}
