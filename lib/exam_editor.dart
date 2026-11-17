import 'package:flutter/material.dart';

import 'study_data.dart';
import 'study_ui.dart';
import 'form_guard.dart';

class ExamSelection {
  const ExamSelection(this.date);
  final DateTime? date;
}

class ExamEditor extends StatefulWidget {
  const ExamEditor({super.key, required this.subject, required this.now});
  final StudySubject subject;
  final DateTime now;
  @override
  State<ExamEditor> createState() => _ExamEditorState();
}

class _ExamEditorState extends State<ExamEditor> {
  late DateTime? date = widget.subject.exam == null
      ? null
      : DateUtils.dateOnly(widget.subject.exam!);
  late TimeOfDay? time =
      widget.subject.exam == null ||
          widget.subject.exam == DateUtils.dateOnly(widget.subject.exam!)
      ? null
      : TimeOfDay.fromDateTime(widget.subject.exam!);
  String? error;
  bool _edited = false;
  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(widget.now);
    final last = DateTime(widget.now.year + 5, 12, 31);
    final selected = await showDatePicker(
      context: context,
      initialDate: date ?? dayOffset(today, 7),
      firstDate: date != null && date!.isBefore(today) ? date! : today,
      lastDate: date != null && date!.isAfter(last) ? date! : last,
    );
    if (selected != null && mounted) {
      setState(() {
        date = selected;
        _edited = true;
        error = null;
      });
    }
  }

  void _save() {
    final day = date;
    final result = day == null
        ? null
        : time == null
        ? day
        : atTime(day, time!.hour, time!.minute);
    final cutoff = result == null
        ? null
        : time == null
        ? dayOffset(result, 1)
        : result;
    if (cutoff != null && !cutoff.isAfter(widget.now)) {
      setState(() => error = tr(context, 'اختر موعد اختبار قادماً.'));
      return;
    }
    Navigator.pop(context, ExamSelection(result));
  }

  @override
  Widget build(BuildContext context) => ConfirmDiscard(
    dirty: _edited,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'تفاصيل الاختبار'))),
      body: SafeArea(
        child: ScreenList(
          children: [
            PageHeading(
              widget.subject.name,
              tr(
                context,
                'أضف موعداً فقط إذا كان لديك اختبار؛ المذاكرة متاحة بدونه.',
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                date == null
                    ? tr(context, 'اختر موعد الاختبار')
                    : MaterialLocalizations.of(context).formatFullDate(date!),
              ),
              onPressed: _pickDate,
            ),
            if (date != null) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time_rounded),
                label: Text(
                  time?.format(context) ?? tr(context, 'أضف وقت الاختبار'),
                ),
                onPressed: () async {
                  final selected = await showTimePicker(
                    context: context,
                    initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (selected != null && mounted) {
                    setState(() {
                      time = selected;
                      _edited = true;
                      error = null;
                    });
                  }
                },
              ),
              if (time != null)
                TextButton(
                  onPressed: () => setState(() {
                    time = null;
                    _edited = true;
                  }),
                  child: Text(tr(context, 'التاريخ فقط')),
                ),
              Text(tr(context, 'الاختبار دون وقت محدد يظهر طوال اليوم.')),
              TextButton(
                onPressed: () => setState(() {
                  date = null;
                  time = null;
                  _edited = true;
                  error = null;
                }),
                child: Text(tr(context, 'إزالة موعد الاختبار')),
              ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: growzaColor(context, amberInk)),
              ),
            StudyButton(tr(context, 'حفظ الاختبار'), _save),
          ],
        ),
      ),
    ),
  );
}
