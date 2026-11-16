import 'package:flutter/material.dart';

import 'study_data.dart';
import 'study_ui.dart';
import 'form_guard.dart';

class ExamEditor extends StatefulWidget {
  const ExamEditor({super.key, required this.subject, required this.now});
  final StudySubject subject;
  final DateTime now;
  @override
  State<ExamEditor> createState() => _ExamEditorState();
}

class _ExamEditorState extends State<ExamEditor> {
  late DateTime date = DateUtils.dateOnly(widget.subject.exam);
  late TimeOfDay? time =
      widget.subject.exam == DateUtils.dateOnly(widget.subject.exam)
      ? null
      : TimeOfDay.fromDateTime(widget.subject.exam);
  String? error;
  bool _edited = false;
  @override
  Widget build(BuildContext context) => ConfirmDiscard(
    dirty: _edited,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, "تفاصيل الاختبار"))),
      body: SafeArea(
        child: ScreenList(
          children: [
            PageHeading(
              widget.subject.name,
              tr(context, "يظهر هذا الاختبار تلقائياً في جدولك."),
            ),
            OutlinedButton.icon(
              icon: Icon(Icons.calendar_today_outlined),
              label: Text(
                MaterialLocalizations.of(context).formatFullDate(date),
              ),
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: date.isBefore(DateUtils.dateOnly(widget.now))
                      ? date
                      : DateUtils.dateOnly(widget.now),
                  lastDate: DateTime(widget.now.year + 5, 12, 31),
                );
                if (selected != null && mounted) {
                  setState(() {
                    date = selected;
                    _edited = true;
                    error = null;
                  });
                }
              },
            ),
            OutlinedButton.icon(
              icon: Icon(Icons.access_time_rounded),
              label: Text(
                time?.format(context) ?? tr(context, "أضف وقت الاختبار"),
              ),
              onPressed: () async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: time ?? TimeOfDay(hour: 9, minute: 0),
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
                child: Text(tr(context, "التاريخ فقط")),
              ),
            Text(tr(context, "الاختبار دون وقت محدد يظهر طوال اليوم.")),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: growzaColor(context, amberInk)),
              ),
            StudyButton(tr(context, "حفظ الاختبار"), () {
              final result = time == null
                  ? date
                  : atTime(date, time!.hour, time!.minute);
              final cutoff = result;
              if (!cutoff.isAfter(widget.now)) {
                setState(() => error = tr(context, "اختر موعد اختبار قادماً."));
                return;
              }
              Navigator.pop(context, result);
            }),
          ],
        ),
      ),
    ),
  );
}
