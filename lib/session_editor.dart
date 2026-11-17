import 'package:flutter/material.dart';

import 'study_input.dart';

import 'study_data.dart';
import 'study_ui.dart';
import 'form_guard.dart';

class SessionEditor extends StatefulWidget {
  const SessionEditor({
    super.key,
    required this.subjects,
    required this.occupied,
    required this.now,
    this.session,
    this.initialDate,
    this.task,
    this.blocked = const [],
  });

  final List<StudySubject> subjects;
  final List<StudySession> occupied;
  final StudySession? session;
  final StudyTask? task;
  final DateTime now;
  final DateTime? initialDate;
  final List<StudyBlock> blocked;

  @override
  State<SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<SessionEditor> {
  final _form = GlobalKey<FormState>();
  late final _topic = TextEditingController(text: widget.session?.topic);
  late final _minutes = TextEditingController(
    text: (widget.session?.minutes ?? 25).toString(),
  );
  DateTime get _now => widget.now;
  late DateTime _start = widget.session?.start ?? _nextAvailableTime();
  late String _subject = widget.session?.subject ?? 'General study';
  String? _error;
  bool _edited = false;

  DateTime _nextAvailableTime() {
    final date = widget.initialDate;
    var start = date != null && !DateUtils.isSameDay(date, _now)
        ? atTime(date, 9)
        : atTime(_now, _now.hour, (_now.minute ~/ 5 + 1) * 5);
    final blocks = <StudyBlock>[
      for (final session in widget.occupied)
        (start: session.start, end: session.endWithBreak),
      ...widget.blocked,
    ]..sort((a, b) => a.start.compareTo(b.start));
    for (final block in blocks) {
      if (start.isBefore(block.end) &&
          block.start.isBefore(start.add(Duration(minutes: 30)))) {
        start = block.end;
      }
    }
    return start;
  }

  @override
  void dispose() {
    _topic.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(_now);
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: _start.isBefore(today) ? DateUtils.dateOnly(_start) : today,
      lastDate: dayOffset(today, 365),
    );
    if (!mounted || date == null) return;
    setState(() {
      _start = atTime(date, _start.hour, _start.minute);
      _edited = true;
      _error = null;
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (!mounted || time == null) return;
    setState(() {
      _start = atTime(_start, time.hour, time.minute);
      _edited = true;
      _error = null;
    });
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final session = StudySession(
      _subject,
      _topic.text.trim(),
      _start,
      int.parse(_minutes.text),
      partId: widget.session?.partId,
      completed: widget.session?.completed ?? false,
      fixed: widget.session?.fixed ?? false,
    );
    if (widget.task case final task?) {
      final exam = task.subject.exam;
      if (exam != null &&
          session.endWithBreak.isAfter(exam) &&
          !session.completed) {
        setState(
          () => _error = tr(context, "يجب أن تنتهي الجلسة قبل موعد الاختبار."),
        );
        return;
      }
    }
    if (widget.occupied.any(session.overlaps)) {
      setState(
        () => _error = tr(context, "يتعارض الوقت مع جلسة أخرى أو استراحتها."),
      );
      return;
    }
    if (widget.blocked.any(
      (block) =>
          session.start.isBefore(block.end) &&
          block.start.isBefore(session.endWithBreak),
    )) {
      setState(() => _error = tr(context, "يتعارض الوقت مع محاضرة مستوردة."));
      return;
    }
    Navigator.pop(context, session);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = {
      'General study',
      for (final subject in widget.subjects) subject.name,
      _subject,
    };
    return ConfirmDiscard(
      dirty: _edited,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.session == null
                ? tr(context, "أضف جلسة")
                : tr(context, "تعديل الجلسة"),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(20, 6, 20, 24),
                child: Form(
                  key: _form,
                  onChanged: () {
                    if (!_edited) setState(() => _edited = true);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _subject,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: tr(context, "المادة"),
                        ),
                        items: [
                          for (final subject in subjects)
                            DropdownMenuItem(
                              value: subject,
                              child: Text(
                                subjectLabel(subject, context: context),
                              ),
                            ),
                        ],
                        onChanged: widget.task != null
                            ? null
                            : (subject) => setState(() => _subject = subject!),
                      ),
                      TextFormField(
                        controller: _topic,
                        readOnly: widget.task != null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: tr(context, "الموضوع"),
                        ),
                        validator: (text) => (text ?? '').trim().isEmpty
                            ? tr(context, "أدخل الموضوع.")
                            : null,
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: Icon(Icons.calendar_today_outlined),
                        label: Text(
                          MaterialLocalizations.of(context)
                              .formatFullDate(_start),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: Icon(Icons.schedule),
                        label: Text(
                          TimeOfDay.fromDateTime(_start).format(context),
                        ),
                      ),
                      TextFormField(
                        controller: _minutes,
                        readOnly: widget.task != null,
                        keyboardType: TextInputType.number,
                        inputFormatters: [studyDigitsFormatter],
                        decoration: InputDecoration(
                          labelText: tr(context, "المدة بالدقائق"),
                        ),
                        validator: (text) {
                          final minutes = int.tryParse(text ?? '');
                          return minutes == null || minutes < 1 || minutes > 720
                              ? tr(context, "أدخل مدة من 1 إلى 720 دقيقة.")
                              : null;
                        },
                      ),
                      if (_error case final message?)
                        copy(
                          message,
                          14,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      StudyButton(tr(context, "حفظ الجلسة"), _save),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
