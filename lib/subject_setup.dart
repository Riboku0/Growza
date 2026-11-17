import 'growth_rules.dart';

import 'pdf_topic_import.dart';
import 'pdf_topics.dart';

import 'package:flutter/material.dart';

import 'study_input.dart';

import 'study_data.dart';
import 'study_ui.dart';
import 'form_guard.dart';

class SubjectSetup extends StatefulWidget {
  const SubjectSetup({
    super.key,
    required this.now,
    this.existingNames = const [],
    this.subject,
    this.part,
    this.remainingTime = false,
    this.pdfPicker,
    this.topicProvider,
  });

  final DateTime Function() now;
  final List<String> existingNames;
  final StudySubject? subject;
  final StudyPart? part;
  final bool remainingTime;
  final StudyPdfPicker? pdfPicker;
  final TopicProvider? topicProvider;

  @override
  State<SubjectSetup> createState() => _SubjectSetupState();
}

class _SubjectSetupState extends State<SubjectSetup> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _title = TextEditingController(text: widget.part?.title);
  late final _minutes = TextEditingController(
    text: (widget.part?.minutes ?? GrowthRules.defaultTopicMinutes).toString(),
  );
  late bool _priority = widget.part?.priority ?? false;
  DateTime? _exam;
  TimeOfDay? _examTime;
  String? _pdfName;
  String? _error;
  bool _pickingPdf = false;
  PdfTopicDraft? _pdfDraft;
  bool get _hasPdfTopics => _pdfDraft?.hasTopics == true;
  bool _multiple = false;
  bool _edited = false;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _pickExam() async {
    final today = DateUtils.dateOnly(widget.now());
    final exam = await showDatePicker(
      context: context,
      initialDate: _exam ?? dayOffset(today, 7),
      firstDate: today,
      lastDate: dayOffset(today, 365),
    );
    if (!mounted || exam == null) return;
    setState(() {
      _exam = exam;
      _edited = true;
      _error = null;
    });
  }

  Future<void> _pickExamTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _examTime ?? TimeOfDay(hour: 12, minute: 0),
    );
    if (!mounted || time == null) return;
    setState(() {
      _examTime = time;
      _edited = true;
      _error = null;
    });
  }

  void _save() {
    final subject = widget.subject;
    final valid = _form.currentState!.validate();
    if (subject == null && _exam == null) {
      setState(() => _error = tr(context, "اختر موعد الاختبار."));
      return;
    }
    if (!valid) return;
    final examTime = _examTime;
    final exam = _exam == null || examTime == null
        ? _exam
        : atTime(_exam!, examTime.hour, examTime.minute);
    if (subject == null && !exam!.isAfter(widget.now())) {
      setState(
        () => _error = examTime == null
            ? tr(context, "أضف وقتاً للاختبار الذي سيُعقد اليوم.")
            : tr(context, "اختر وقت اختبار قادماً."),
      );
      return;
    }
    if (_hasPdfTopics) {
      if (!_pdfDraft!.valid || _pickingPdf) return;
      final base = subject ?? StudySubject(_name.text.trim(), exam!, []);
      Navigator.pop(context, appendPdfTopics(base, _pdfDraft!));
      return;
    }
    final current = widget.part;
    final titles = _multiple
        ? _title.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
        : [_title.text.trim()];
    if (titles.length > 100 ||
        titles.map((s) => s.toLowerCase()).toSet().length != titles.length) {
      setState(
        () =>
            _error = tr(context, "أدخل حتى 100 موضوع مختلف، كل موضوع في سطر."),
      );
      return;
    }
    final existingTitles = {
      for (final p in subject?.parts ?? <StudyPart>[])
        if (p.id != current?.id) p.title.toLowerCase(),
    };
    if (titles.any((s) => existingTitles.contains(s.toLowerCase()))) {
      setState(() => _error = tr(context, "يوجد موضوع بهذا الاسم بالفعل."));
      return;
    }
    final nextId = subject?.nextPartId ?? 1;
    final added = [
      for (var i = 0; i < titles.length; i++)
        StudyPart(
          current?.id ?? nextId + i,
          titles[i],
          int.parse(_minutes.text),
          priority: _priority,
          completed: current?.completed ?? false,
          startPage: current?.startPage,
          endPage: current?.endPage,
          pdfName: _pdfName ?? current?.pdfName,
        ),
    ];
    final result = subject == null
        ? StudySubject(_name.text.trim(), exam!, added, pdfName: _pdfName)
        : subject.withParts([
            for (final p in subject.parts)
              p.id == current?.id ? added.first : p,
            if (current == null) ...added,
          ]);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final addingSubject = subject == null;
    final title = addingSubject
        ? tr(context, "أضف مادة")
        : widget.remainingTime
        ? tr(context, "كم بقي من الوقت؟")
        : widget.part == null
        ? tr(context, "أضف موضوعاً")
        : tr(context, "تعديل الموضوع");
    return ConfirmDiscard(
      dirty: _edited,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
                child: Form(
                  key: _form,
                  onChanged: () {
                    if (!_edited) setState(() => _edited = true);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      PageHeading(
                        addingSubject
                            ? tr(context, "أضف مادتك ومواضيعها")
                            : subject.name,
                        addingSubject
                            ? tr(
                                context,
                                "اختر PDF لاستخراج مواضيع المذاكرة أو أضفها يدوياً.",
                              )
                            : widget.remainingTime
                            ? tr(
                                context,
                                "يبقى الموضوع مفتوحاً. حدّث الدقائق التي ما زلت تحتاجها.",
                              )
                            : tr(
                                context,
                                "اختر عملاً محدداً يمكنك إنجازه في جلسة.",
                              ),
                        eyebrow: tr(context, "خطة مذاكرتك"),
                      ),
                      if (addingSubject) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: tr(context, "اسم المادة"),
                            hintText: tr(context, "مثال: الرياضيات"),
                          ),
                          validator: (value) {
                            final name = value!.trim();
                            if (name.isEmpty) {
                              return tr(context, "أدخل اسم المادة.");
                            }
                            if (widget.existingNames.contains(
                                  name.toLowerCase(),
                                ) ||
                                [
                                  'general study',
                                  'مذاكرة عامة',
                                ].contains(name.toLowerCase())) {
                              return tr(context, "اختر اسماً آخر للمادة.");
                            }
                            return null;
                          },
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickExam,
                          icon: Icon(Icons.calendar_today_outlined),
                          label: Text(
                            _exam == null
                                ? tr(context, "اختر موعد الاختبار")
                                : MaterialLocalizations.of(context)
                                      .formatFullDate(_exam!),
                          ),
                        ),
                        if (_exam != null)
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _pickExamTime,
                                icon: Icon(Icons.access_time_rounded, size: 18),
                                label: Text(
                                  _examTime?.format(context) ??
                                      tr(context, "أضف وقت الاختبار (اختياري)"),
                                ),
                              ),
                              if (_examTime != null)
                                TextButton(
                                  onPressed: () => setState(() {
                                    _examTime = null;
                                    _edited = true;
                                  }),
                                  child: Text(tr(context, "إزالة الوقت")),
                                ),
                            ],
                          ),
                      ],
                      if (widget.part == null)
                        PdfTopicImport(
                          provider: widget.topicProvider,
                          pick: widget.pdfPicker,
                          existingTitles: [
                            for (final p in subject?.parts ?? <StudyPart>[])
                              p.title,
                          ],
                          onChanged: (draft) => setState(() {
                            _pdfDraft = draft;
                            _pdfName = draft?.fileName;
                            _edited = true;
                          }),
                          onBusyChanged: (busy) =>
                              setState(() => _pickingPdf = busy),
                        ),
                      if (!_hasPdfTopics) ...[
                        if (widget.part == null)
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(tr(context, "موضوع واحد")),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(tr(context, "عدة مواضيع")),
                              ),
                            ],
                            selected: {_multiple},
                            onSelectionChanged: (value) =>
                                setState(() => _multiple = value.first),
                          ),
                        TextFormField(
                          maxLines: _multiple ? 6 : 1,
                          controller: _title,
                          keyboardType: _multiple
                              ? TextInputType.multiline
                              : TextInputType.text,
                          readOnly: widget.remainingTime,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: _multiple
                              ? TextInputAction.newline
                              : TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: _multiple
                                ? tr(
                                    context,
                                    "مواضيع المذاكرة · كل موضوع في سطر",
                                  )
                                : addingSubject
                                ? tr(context, "أول موضوع للمذاكرة")
                                : tr(context, "موضوع المذاكرة"),
                            hintText: tr(context, "مثال: حل تمارين التكامل"),
                          ),
                          validator: (value) => value!.trim().isEmpty
                              ? tr(context, "أدخل موضوع المذاكرة.")
                              : null,
                        ),
                        TextFormField(
                          controller: _minutes,
                          keyboardType: TextInputType.number,
                          inputFormatters: [studyDigitsFormatter],
                          decoration: InputDecoration(
                            labelText: widget.remainingTime
                                ? tr(context, "الدقائق المتبقية")
                                : tr(context, "دقائق التركيز المقدّرة"),
                            helperText: widget.remainingTime
                                ? null
                                : _multiple
                                ? tr(
                                    context,
                                    "يُطبّق التقدير على كل موضوع، ويمكنك تعديل كل موضوع لاحقاً.",
                                  )
                                : tr(
                                    context,
                                    "ابدأ بـ25 دقيقة، وعدّلها متى شئت.",
                                  ),
                          ),
                          validator: (value) {
                            final minutes = int.tryParse(value!);
                            return minutes == null ||
                                    minutes < 1 ||
                                    minutes > 720
                                ? tr(context, "أدخل مدة من 1 إلى 720 دقيقة.")
                                : null;
                          },
                        ),
                        if (!widget.remainingTime)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _priority,
                            onChanged: (value) => setState(() {
                              _priority = value!;
                              _edited = true;
                            }),
                            title: Text(tr(context, "اجعل هذا الموضوع أولوية")),
                          ),
                      ],
                      if (_error case final error?)
                        copy(
                          error,
                          13,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      StudyButton(
                        addingSubject
                            ? tr(context, "حفظ المادة")
                            : tr(context, "حفظ الموضوع"),
                        _pickingPdf || (_hasPdfTopics && !_pdfDraft!.valid)
                            ? null
                            : _save,
                      ),
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
