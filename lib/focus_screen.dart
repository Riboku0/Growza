import 'app_strings.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'focus_timer.dart';
import 'focus_record.dart';
import 'growth_ledger.dart';
import 'plant_visual.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({
    super.key,
    required this.timer,
    required this.topic,
    required this.subject,
    this.growth,
    this.notice,
    this.returnOnFocusEnd = false,
  });
  final FocusTimer timer;
  final String topic;
  final String subject;
  final PlantGrowth Function()? growth;
  final String? Function()? notice;
  final bool returnOnFocusEnd;
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _closing = false;
  bool _endDialogOpen = false;
  late bool _wasFocus = widget.timer.phase == TimerPhase.focus;
  @override
  void initState() {
    super.initState();
    widget.timer.addListener(_changed);
  }

  @override
  void dispose() {
    widget.timer.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!_closing &&
        _wasFocus &&
        widget.timer.phase != TimerPhase.focus &&
        widget.returnOnFocusEnd) {
      _closing = true;
      final record = widget.timer.lastRecord;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_endDialogOpen) Navigator.pop(context, false);
        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context, record);
        }
      });
    }
    _wasFocus = widget.timer.phase == TimerPhase.focus;
  }

  Future<void> _confirmEnd() async {
    _endDialogOpen = true;
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'إنهاء جلسة التركيز؟')),
        content: Text(
          tr(
            context,
            'سيُحفظ وقت تركيزك الفعلي. يمكنك تأكيد المواضيع التي أنهيتها بعد ذلك.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'متابعة التركيز')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'إنهاء الجلسة')),
          ),
        ],
      ),
    );
    _endDialogOpen = false;
    if (end == true && mounted && !_closing) _end();
  }

  void _end() {
    _closing = true;
    final record = widget.timer.finishFocus();
    if (Navigator.canPop(context)) Navigator.pop<FocusRecord>(context, record);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => Navigator.pop(context)),
      centerTitle: true,
      title: Text(
        widget.subject,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.timer,
        builder: (context, _) {
          final timer = widget.timer;
          final focus = timer.phase == TimerPhase.focus;
          final finished = timer.phase == TimerPhase.finished;
          final total =
              (timer.remaining.inMicroseconds / Duration.microsecondsPerSecond)
                  .ceil();
          final clock =
              '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
          final growth = widget.growth?.call();
          final note = widget.notice?.call();
          final label = timer.isRunning
              ? tr(context, "إيقاف مؤقت")
              : focus
              ? (timer.focused > Duration.zero
                    ? tr(context, "متابعة")
                    : tr(context, "ابدأ التركيز"))
              : tr(context, "ابدأ الاستراحة");
          return LayoutBuilder(
            builder: (context, bounds) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(24, 12, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, bounds.maxHeight - 36),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            if (!focus)
                              Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  finished
                                      ? tr(context, "انتهت الاستراحة")
                                      : tr(context, "وقت الاستراحة"),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: growzaColor(context, muted),
                                  ),
                                ),
                              ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                clock,
                                textDirection: TextDirection.ltr,
                                key: ValueKey('focus-clock'),
                                style: TextStyle(
                                  fontSize: 64,
                                  fontFamily: 'Roboto',
                                  height: 1.1,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0,
                                  color: growzaColor(context, ink),
                                ),
                              ),
                            ),
                            if (!timer.isRunning &&
                                !finished &&
                                timer.remaining < timer.phaseLength)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  tr(context, "متوقف مؤقتاً"),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: growzaColor(context, muted),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(
                          key: ValueKey('focus-plant'),
                          width: 300,
                          height: (bounds.maxHeight * .46).clamp(170.0, 340.0),
                          child: StudyPlant(
                            centered: true,
                            visualState: timer.isRunning
                                ? PlantVisualState.breathing
                                : PlantVisualState.calm,
                            units:
                                growth?.visualUnits ??
                                plantUnits(timer.focused),
                            flowers: growth?.topicProgress ?? 0,
                            animate: false,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (note != null)
                              Padding(
                                padding: EdgeInsets.only(bottom: 18),
                                child: Text(
                                  translatedMessage(context, note),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: growzaColor(context, greenInk),
                                  ),
                                ),
                              ),
                            if (!finished)
                              FilledButton(
                                onPressed: timer.toggle,
                                child: Text(label),
                              ),
                            SizedBox(height: 8),
                            if (focus)
                              TextButton(
                                onPressed: _confirmEnd,
                                child: Text(tr(context, "إنهاء الجلسة")),
                              )
                            else
                              TextButton(
                                onPressed: () {
                                  if (timer.isRunning) timer.toggle();
                                  Navigator.pop(context);
                                },
                                child: Text(tr(context, "تم")),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
