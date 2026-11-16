import 'growth_rules.dart';

import 'package:file_selector/file_selector.dart';
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
  });

  final DateTime Function() now;
  final List<String> existingNames;
  final StudySubject? subject;
  final StudyPart? part;
  final bool remainingTime;

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

  Future<void> _pickPdf() async {
    setState(() => _pickingPdf = true);
    try {
      final pdf = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: tr(context, "ملفات PDF"),
            extensions: ['pdf'],
            mimeTypes: ['application/pdf'],
            uniformTypeIdentifiers: ['com.adobe.pdf'],
          ),
        ],
      );
      if (!mounted || pdf == null) return;
      setState(() {
        if (pdf.name.toLowerCase().endsWith('.pdf')) {
          _pdfName = pdf.name;
          _edited = true;
          _error = null;
        } else {
          _error = tr(context, "اختر ملف PDF.");
        }
      });
    } on Exception {
      if (mounted) {
        setState(() => _error = tr(context, "تعذّر اختيار ملف PDF."));
      }
    } finally {
      if (mounted) setState(() => _pickingPdf = false);
    }
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
                            ? tr(context, "ابدأ بموضوع واحد")
                            : subject.name,
                        addingSubject
                            ? tr(
                                context,
                                "أضف أول موضوع تريد مذاكرته. يمكنك إضافة المزيد لاحقاً.",
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
                              ? tr(context, "مواضيع المذاكرة · كل موضوع في سطر")
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
                          return minutes == null || minutes < 1 || minutes > 720
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
                      if (addingSubject)
                        Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              copy(
                                tr(context, "مرجع PDF · اختياري"),
                                14,
                                weight: FontWeight.w700,
                              ),
                              copy(
                                _pdfName ??
                                    tr(
                                      context,
                                      "مرجع اختياري باسم الملف فقط. لا يُقرأ محتوى PDF ولا يُحلّل.",
                                    ),
                                13,
                                color: growzaColor(context, muted),
                              ),
                              Wrap(
                                spacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickingPdf ? null : _pickPdf,
                                    icon: Icon(Icons.picture_as_pdf_outlined),
                                    label: Text(
                                      _pdfName == null
                                          ? tr(context, "اختر ملف PDF")
                                          : tr(context, "تغيير ملف PDF"),
                                    ),
                                  ),
                                  if (_pdfName != null)
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _pdfName = null;
                                        _edited = true;
                                      }),
                                      child: Text(tr(context, "إزالة")),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                        _pickingPdf ? null : _save,
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
