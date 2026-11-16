import 'dart:async';

import 'package:flutter/foundation.dart';

import 'focus_record.dart';
import 'growth_rules.dart';
import 'local_id.dart';

const studyBreak = Duration(minutes: 5);

enum TimerPhase { focus, rest, finished }

class FocusTimer extends ChangeNotifier {
  FocusTimer({
    required this.focusLength,
    required this.onFocusCompleted,
    this.onFocusRecorded,
    this.subjectId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _remaining = focusLength;

  factory FocusTimer.restore(
    Map<String, dynamic> json, {
    required VoidCallback onFocusCompleted,
    ValueChanged<FocusRecord>? onFocusRecorded,
    String? subjectId,
    DateTime Function()? now,
  }) {
    final length = json['focusMs'] as int;
    final remaining = json['remainingMs'] as int;
    final phase = TimerPhase.values.byName(json['phase'] as String);
    if (length < 1 ||
        length > const Duration(hours: 24).inMilliseconds ||
        remaining < 0) {
      throw const FormatException('Invalid timer snapshot');
    }
    final savedGrowth = json['growth'];
    final growth = savedGrowth == null
        ? null
        : Map<String, dynamic>.from(savedGrowth as Map);
    final timer = FocusTimer(
      focusLength: Duration(milliseconds: length),
      onFocusCompleted: onFocusCompleted,
      onFocusRecorded: onFocusRecorded,
      subjectId: growth?['subjectId'] as String? ?? subjectId,
      now: now,
    );
    timer._phase = phase;
    if (remaining > timer.phaseLength.inMilliseconds) {
      throw const FormatException('Invalid remaining time');
    }
    timer._remaining = Duration(milliseconds: remaining);
    timer._deadline = json['deadline'] == null
        ? null
        : DateTime.parse(json['deadline'] as String);
    if (phase == TimerPhase.finished) timer._deadline = null;
    if (growth != null) {
      timer._recordId = growth['id'] as String;
      timer._settled = growth['settled'] as bool;
      timer._legacyTiming = growth['legacy'] as bool? ?? false;
      timer._spans.addAll(
        (growth['spans'] as List).map(
          (span) => FocusSpan.fromJson(Map<String, dynamic>.from(span as Map)),
        ),
      );
      timer._runningFocusStart = growth['runningSince'] == null
          ? null
          : DateTime.parse(growth['runningSince'] as String);
      if (timer._storedFocus > timer.focusLength || timer._recordId.isEmpty) {
        throw const FormatException('Invalid focus history');
      }
      DateTime? previous;
      for (final span in timer._spans) {
        if (previous != null && span.start.isBefore(previous)) {
          throw const FormatException('Overlapping focus history');
        }
        previous = span.end;
      }
      if (timer._runningFocusStart case final start?) {
        if (timer._deadline == null ||
            phase != TimerPhase.focus ||
            timer._settled ||
            start.isAfter(timer._deadline!) ||
            (previous != null && start.isBefore(previous))) {
          throw const FormatException('Invalid active focus interval');
        }
      } else if (phase == TimerPhase.focus && timer._deadline != null) {
        throw const FormatException('Missing active focus interval');
      }
    } else {
      // Old snapshots know elapsed active duration, but not the original pause
      // positions. Preserve that duration without treating downtime as focus.
      timer._legacyTiming = true;
      timer._settled = phase != TimerPhase.focus;
      if (phase == TimerPhase.focus) {
        final spent = timer.focusLength - timer._remaining;
        final boundary =
            timer._deadline?.subtract(timer._remaining) ?? timer._now();
        if (spent > Duration.zero) {
          timer._spans.add(FocusSpan(boundary.subtract(spent), boundary));
        }
        if (timer._deadline != null) timer._runningFocusStart = boundary;
      }
    }
    if (timer._deadline != null) timer._startTicker();
    return timer;
  }

  final Duration focusLength;
  final VoidCallback onFocusCompleted;
  final ValueChanged<FocusRecord>? onFocusRecorded;
  final String? subjectId;
  final DateTime Function() _now;
  TimerPhase _phase = TimerPhase.focus;
  Duration _remaining;
  DateTime? _deadline;
  Timer? _ticker;
  String _recordId = newLocalId('focus');
  final _spans = <FocusSpan>[];
  DateTime? _runningFocusStart;
  bool _settled = false;
  bool _legacyTiming = false;
  FocusRecord? _lastRecord;

  TimerPhase get phase => _phase;
  Duration get remaining => _remaining;
  Duration get phaseLength =>
      _phase == TimerPhase.focus ? focusLength : studyBreak;
  bool get isRunning => _deadline != null;
  bool get hasProgress =>
      _phase != TimerPhase.finished &&
      !(_phase == TimerPhase.focus && _settled) &&
      (isRunning || _phase == TimerPhase.rest || _remaining != focusLength);
  Duration get _storedFocus =>
      _spans.fold(Duration.zero, (total, span) => total + span.duration);
  Duration get focused {
    final start = _runningFocusStart;
    if (start == null) return _storedFocus;
    final available = focusLength - _storedFocus;
    final elapsed = _now()
        .difference(start)
        .inMilliseconds
        .clamp(0, available.inMilliseconds);
    return _storedFocus + Duration(milliseconds: elapsed);
  }

  bool get canFinishWithGrace =>
      GrowthRules.countsAsCompleted(focused, focusLength);
  FocusRecord? get lastRecord => _lastRecord;
  String get recordId => _recordId;

  // Read-only live preview. It never settles a record or awards growth.
  FocusRecord? previewRecord() {
    if (_settled) return _lastRecord;
    final spans = [..._spans];
    final now = _now();
    if (_runningFocusStart case final start?) {
      final maxEnd = start.add(focusLength - _storedFocus);
      final end = now.isBefore(maxEnd) ? now : maxEnd;
      if (end.isAfter(start)) spans.add(FocusSpan(start, end));
    }
    if (spans.isEmpty) return null;
    return FocusRecord(
      id: _recordId,
      subjectId: subjectId,
      planned: focusLength,
      endedAt: now.isBefore(spans.last.end) ? spans.last.end : now,
      spans: spans,
      completed: GrowthRules.countsAsCompleted(focused, focusLength),
      legacy: _legacyTiming,
    );
  }

  Map<String, dynamic> toJson() => {
    'focusMs': focusLength.inMilliseconds,
    'remainingMs': remaining.inMilliseconds,
    'phase': phase.name,
    'deadline': _deadline?.toUtc().toIso8601String(),
    'growth': {
      'id': _recordId,
      'subjectId': subjectId,
      'spans': _spans.map((span) => span.toJson()).toList(),
      'runningSince': _runningFocusStart?.toUtc().toIso8601String(),
      'settled': _settled,
      'legacy': _legacyTiming,
    },
  };
  String get persistenceKey =>
      '$_recordId|${phase.name}|${_deadline?.toUtc().toIso8601String()}|${isRunning ? 0 : remaining.inMilliseconds}';

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => refresh(),
    );
  }

  void toggle() {
    if (_phase == TimerPhase.finished) return;
    if (isRunning) {
      refresh();
      _closeFocusSpan(_now());
      _stop();
    } else {
      _deadline = _now().add(_remaining);
      if (_phase == TimerPhase.focus) _runningFocusStart = _now();
      _startTicker();
    }
    notifyListeners();
  }

  void _closeFocusSpan(DateTime until) {
    final start = _runningFocusStart;
    if (start == null) return;
    final available = focusLength - _storedFocus;
    final maxEnd = start.add(available);
    final end = until.isBefore(maxEnd) ? until : maxEnd;
    if (end.isAfter(start)) _spans.add(FocusSpan(start, end));
    _runningFocusStart = null;
  }

  FocusRecord? _settle(bool completed, DateTime endedAt) {
    if (_settled) return _lastRecord;
    _settled = true;
    if (_storedFocus <= Duration.zero) return null;
    final lastEnd = _spans.last.end;
    final record = FocusRecord(
      id: _recordId,
      subjectId: subjectId,
      planned: focusLength,
      endedAt: endedAt.isBefore(lastEnd) ? lastEnd : endedAt,
      spans: _spans,
      completed: completed,
      legacy: _legacyTiming,
    );
    _lastRecord = record;
    onFocusRecorded?.call(record);
    return record;
  }

  void _newCycle() {
    _recordId = newLocalId('focus');
    _spans.clear();
    _runningFocusStart = null;
    _settled = false;
    _legacyTiming = false;
    _lastRecord = null;
    _phase = TimerPhase.focus;
    _remaining = focusLength;
  }

  // Explicit end for the next UI stage. Backgrounding or disposal never calls it.
  // A partial session retains its active minutes; the ledger decides its growth.
  FocusRecord? finishFocus() {
    refresh();
    if (_phase != TimerPhase.focus) return _lastRecord;
    final endedAt = _now();
    _closeFocusSpan(endedAt);
    _stop();
    final completed = GrowthRules.countsAsCompleted(_storedFocus, focusLength);
    if (completed) {
      _phase = TimerPhase.rest;
      _remaining = studyBreak;
    }
    final record = _settle(completed, endedAt);
    if (completed) {
      onFocusCompleted();
    } else {
      _newCycle();
    }
    notifyListeners();
    return record;
  }

  void reset() {
    refresh();
    if (_phase == TimerPhase.focus) {
      final endedAt = _now();
      _closeFocusSpan(endedAt);
      _stop();
      _settle(false, endedAt);
      _newCycle();
    } else {
      _stop();
      if (_phase == TimerPhase.finished) {
        _newCycle();
      } else {
        _remaining = studyBreak;
      }
    }
    notifyListeners();
  }

  void refresh() {
    final deadline = _deadline;
    if (deadline == null) return;
    final left = deadline.difference(_now());
    if (left > Duration.zero) {
      _remaining = left > phaseLength ? phaseLength : left;
    } else if (_phase == TimerPhase.focus) {
      _closeFocusSpan(deadline);
      _stop();
      _phase = TimerPhase.rest;
      _remaining = studyBreak;
      _settle(true, deadline);
      onFocusCompleted();
    } else {
      _stop();
      _phase = TimerPhase.finished;
      _remaining = Duration.zero;
    }
    notifyListeners();
  }

  void _stop() {
    _deadline = null;
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}
