import 'package:flutter/material.dart';

import 'study_input.dart';

import 'study_data.dart';
import 'study_planner.dart';
import 'study_ui.dart';

class PlanReview extends StatefulWidget {
  const PlanReview({
    super.key,
    required this.tasks,
    required this.sessions,
    required this.now,
    this.blocked = const [],
  });

  final List<StudyTask> tasks;
  final List<StudySession> sessions;
  final DateTime Function() now;
  final List<StudyBlock> blocked;

  @override
  State<PlanReview> createState() => _PlanReviewState();
}

class _PlanReviewState extends State<PlanReview> {
  final _minutes = TextEditingController(text: '60');
  late DateTime _start = _nextMinute(widget.now());
  bool _startNow = true;
  StudyPlan? _preview;
  String? _error;

  DateTime _nextMinute(DateTime now) =>
      atTime(now, now.hour, now.minute).add(Duration(minutes: 1));

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = widget.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _start.isBefore(now) ? now : _start,
      firstDate: DateUtils.dateOnly(now),
      lastDate: dayOffset(now, 365),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (!mounted || time == null) return;
    setState(() {
      _startNow = false;
      _start = atTime(date, time.hour, time.minute);
      _error = null;
    });
  }

  void _review() {
    final minutes = int.tryParse(_minutes.text);
    final now = widget.now();
    final start = _startNow ? _nextMinute(now) : _start;
    if (minutes == null || minutes < 1 || minutes > 720) {
      setState(
        () => _error = tr(context, "أدخل وقتاً متاحاً من 1 إلى 720 دقيقة."),
      );
      return;
    }
    if (start.isBefore(now)) {
      setState(() => _error = tr(context, "اختر وقت بدء قادماً."));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _start = start;
      _preview = StudyPlan.fit(
        tasks: widget.tasks,
        sessions: widget.sessions,
        now: now,
        start: start,
        end: start.add(Duration(minutes: minutes)),
        blocked: widget.blocked,
      );
    });
  }

  void _apply() {
    final plan = _preview!;
    final now = widget.now();
    if (plan.scheduled.any((session) => session.start.isBefore(now))) {
      setState(() {
        _preview = null;
        _error = tr(context, "مضى وقت بدء مقترح. راجع فترة جديدة.");
      });
      return;
    }
    Navigator.pop(context, plan);
  }

  List<Widget> _timeInput(BuildContext context) => [
    PageHeading(
      tr(context, "تغيّر وقتك؟"),
      tr(
        context,
        "حدّد وقتك المتاح، وراجع ما يمكنك إنجازه وما يحتاج وقتاً آخر.",
      ),
      eyebrow: tr(context, "عدّل خطتك"),
    ),
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          copy(tr(context, "متى يمكنك البدء؟"), 16, weight: FontWeight.w700),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text(tr(context, "الآن")),
                selected: _startNow,
                onSelected: (_) => setState(() {
                  _startNow = true;
                  _error = null;
                }),
              ),
              OutlinedButton.icon(
                onPressed: _pickStart,
                icon: Icon(Icons.event_outlined),
                label: Text(
                  _startNow
                      ? tr(context, "اختر وقتاً")
                      : '${dayLabel(context, _start)} · ${clockLabel(_start)}',
                ),
              ),
            ],
          ),
          copy(tr(context, "كم لديك من الوقت؟"), 16, weight: FontWeight.w700),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final minutes in [25, 45, 60, 90])
                ChoiceChip(
                  label: Text(tr(context, "{0} د", [minutes])),
                  selected: _minutes.text == '$minutes',
                  onSelected: (_) => setState(() {
                    _minutes.text = '$minutes';
                    _error = null;
                  }),
                ),
            ],
          ),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            inputFormatters: [studyDigitsFormatter],
            decoration: InputDecoration(
              labelText: tr(context, "الدقائق المتاحة"),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          copy(
            tr(context, "تشمل الفترة استراحة 5 دقائق بعد كل موضوع."),
            13,
            color: growzaColor(context, muted),
          ),
        ],
      ),
    ),
    if (_error case final error?)
      copy(error, 13, color: Theme.of(context).colorScheme.error),
    StudyButton(tr(context, "مراجعة التغييرات"), _review),
  ];

  List<Widget> _planPreview(BuildContext context, StudyPlan plan) {
    final end = _start.add(Duration(minutes: int.parse(_minutes.text)));
    final endLabel = DateUtils.isSameDay(_start, end)
        ? clockLabel(end)
        : '${dayLabel(context, end)} · ${clockLabel(end)}';
    return [
      PageHeading(
        tr(context, "راجع خطتك"),
        tr(context, "{0} · من {1} إلى {2}", [
          dayLabel(context, _start),
          clockLabel(_start),
          endLabel,
        ]),
        eyebrow: tr(context, "راجع قبل الحفظ"),
      ),
      Panel(
        color: growzaColor(context, accentSoft),
        bordered: false,
        child: Text(
          tr(
            context,
            "تُعطى الأولوية للاختبارات الأقرب. تبقى الجلسات المكتملة واليدوية والثابتة كما هي.",
          ),
        ),
      ),
      copy(tr(context, "ما يناسب هذه الفترة"), 18, weight: FontWeight.w700),
      if (plan.scheduled.isEmpty)
        Panel(
          child: Text(
            plan.unscheduled.isEmpty
                ? tr(context, "المواضيع المتبقية مجدولة بالفعل.")
                : tr(context, "لا تتسع الفترة لموضوع كامل."),
          ),
        ),
      for (final session in plan.scheduled) ...[
        SessionTile(session),
        if (plan.replaced[session.partKey] case final old?)
          if (old.start != session.start || old.minutes != session.minutes)
            copy(
              tr(context, "سابقاً: {0} الساعة {1} · {2} د", [
                dayLabel(context, old.start),
                clockLabel(old.start),
                old.minutes,
              ]),
              12,
              color: growzaColor(context, muted),
            ),
      ],
      if (plan.unscheduled.isNotEmpty)
        Panel(
          color: growzaColor(context, amberLight),
          bordered: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              copy(
                tr(context, "ما زال يحتاج وقتاً"),
                18,
                color: growzaColor(context, amberInk),
                weight: FontWeight.w700,
              ),
              copy(
                tr(context, "دقائق التركيز غير المجدولة: {0}.", [
                  plan.unscheduledMinutes,
                ]),
                13,
                color: growzaColor(context, amberInk),
              ),
              for (final task in plan.unscheduled) ...[
                copy(
                  tr(context, "{0} · {1} · {2} د", [
                    task.subject.name,
                    task.part.title,
                    task.part.minutes,
                  ]),
                  14,
                  weight: FontWeight.w600,
                ),
                if (plan.replaced[task.key] case final previous?)
                  copy(
                    tr(context, "سيُزال موعد {0} الساعة {1}.", [
                      dayLabel(context, previous.start),
                      clockLabel(previous.start),
                    ]),
                    12,
                    color: growzaColor(context, amberInk),
                  ),
                if (task.subject.exam != null &&
                    !_start.isBefore(task.subject.exam!))
                  copy(
                    tr(context, "تبدأ هذه الفترة بعد موعد الاختبار."),
                    12,
                    color: growzaColor(context, amberInk),
                  ),
              ],
            ],
          ),
        ),
      if (plan.hasChanges) StudyButton(tr(context, "تطبيق التغييرات"), _apply),
      StudyButton(
        tr(context, "تغيير الوقت"),
        () => setState(() => _preview = null),
        secondary: plan.hasChanges,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, "تعديل خطة المذاكرة"))),
      body: SafeArea(
        child: ScreenList(
          key: ValueKey(preview != null),
          children: preview == null
              ? _timeInput(context)
              : _planPreview(context, preview),
        ),
      ),
    );
  }
}
