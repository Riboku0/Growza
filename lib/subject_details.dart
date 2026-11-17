import 'pdf_topic_import.dart';
import 'pdf_topics.dart';

import 'package:flutter/material.dart';

import 'form_guard.dart';
import 'study_data.dart';
import 'study_ui.dart';

class SubjectDetails extends StatefulWidget {
  const SubjectDetails({
    super.key,
    required this.subject,
    required this.existingNames,
    this.pdfPicker,
    this.topicProvider,
  });
  final StudySubject subject;
  final List<String> existingNames;
  final StudyPdfPicker? pdfPicker;
  final TopicProvider? topicProvider;
  @override
  State<SubjectDetails> createState() => _SubjectDetailsState();
}

class _SubjectDetailsState extends State<SubjectDetails> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.subject.name);
  late String? _pdf = widget.subject.pdfName;
  bool _picking = false;
  PdfTopicDraft? _draft;
  bool get _dirty =>
      _name.text.trim() != widget.subject.name ||
      _pdf != widget.subject.pdfName ||
      _draft?.hasTopics == true;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConfirmDiscard(
    dirty: _dirty,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, "تعديل المادة"))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(22, 12, 22, 28),
              child: Form(
                key: _form,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    PageHeading(
                      tr(context, "تفاصيل المادة"),
                      tr(
                        context,
                        "يبقى تقدمك وجلساتك مرتبطين بالمادة عند تغيير اسمها.",
                      ),
                    ),
                    TextFormField(
                      controller: _name,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: tr(context, "اسم المادة"),
                      ),
                      validator: (text) {
                        final value = (text ?? '').trim();
                        if (value.isEmpty) {
                          return tr(context, "أدخل اسم المادة.");
                        }
                        if ([
                              'general study',
                              'مذاكرة عامة',
                            ].contains(value.toLowerCase()) ||
                            widget.existingNames.any(
                              (name) =>
                                  name.toLowerCase() == value.toLowerCase() &&
                                  name != widget.subject.name,
                            )) {
                          return tr(context, "اختر اسماً آخر للمادة.");
                        }
                        return null;
                      },
                    ),
                    PdfTopicImport(
                      pdfName: widget.subject.pdfName,
                      provider: widget.topicProvider,
                      pick: widget.pdfPicker,
                      existingTitles: widget.subject.parts
                          .map((p) => p.title)
                          .toList(),
                      onChanged: (draft) => setState(() {
                        _draft = draft;
                        _pdf = draft?.fileName;
                      }),
                      onBusyChanged: (busy) => setState(() => _picking = busy),
                    ),
                    StudyButton(
                      tr(context, "حفظ تفاصيل المادة"),
                      _picking || (_draft?.valid == false)
                          ? null
                          : () {
                              if (!_form.currentState!.validate()) return;
                              final edited = StudySubject(
                                _name.text.trim(),
                                widget.subject.exam,
                                widget.subject.parts,
                                id: widget.subject.id,
                                pdfName: _pdf,
                                nextPartId: widget.subject.nextPartId,
                              );
                              Navigator.pop(
                                context,
                                _draft?.hasTopics == true
                                    ? appendPdfTopics(
                                        edited,
                                        _draft!,
                                        updateReference: true,
                                      )
                                    : edited,
                              );
                            },
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
