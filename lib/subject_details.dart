import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'form_guard.dart';
import 'study_data.dart';
import 'study_ui.dart';

class SubjectDetails extends StatefulWidget {
  const SubjectDetails({
    super.key,
    required this.subject,
    required this.existingNames,
  });
  final StudySubject subject;
  final List<String> existingNames;
  @override
  State<SubjectDetails> createState() => _SubjectDetailsState();
}

class _SubjectDetailsState extends State<SubjectDetails> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.subject.name);
  late String? _pdf = widget.subject.pdfName;
  bool _picking = false;
  String? _error;
  bool get _dirty =>
      _name.text.trim() != widget.subject.name ||
      _pdf != widget.subject.pdfName;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePdf() async {
    setState(() => _picking = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: tr(context, "ملفات PDF"),
            extensions: ['pdf'],
            mimeTypes: ['application/pdf'],
            uniformTypeIdentifiers: ['com.adobe.pdf'],
          ),
        ],
      );
      if (!mounted || file == null) return;
      setState(() {
        if (file.name.toLowerCase().endsWith('.pdf')) {
          _pdf = file.name;
          _error = null;
        } else {
          _error = tr(context, "اختر ملف PDF.");
        }
      });
    } on Exception {
      if (mounted) {
        setState(
          () => _error = tr(context, "تعذّر اختيار ملف PDF. حاول مجدداً."),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
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
                    copy(tr(context, "مرجع PDF"), 16, weight: FontWeight.w600),
                    Text(
                      tr(
                        context,
                        "مرجع اختياري باسم الملف فقط؛ لا يُحلّل محتواه ولا ينشئ مواضيع مذاكرة.",
                      ),
                    ),
                    if (_pdf != null) Text(_pdf!),
                    OutlinedButton.icon(
                      onPressed: _picking ? null : _choosePdf,
                      icon: Icon(Icons.attach_file_rounded),
                      label: Text(
                        _picking
                            ? tr(context, "جارٍ اختيار الملف…")
                            : _pdf == null
                            ? tr(context, "اختر ملف PDF")
                            : tr(context, "استبدال ملف PDF"),
                      ),
                    ),
                    if (_pdf != null)
                      TextButton(
                        onPressed: _picking
                            ? null
                            : () => setState(() => _pdf = null),
                        child: Text(tr(context, "إزالة مرجع PDF")),
                      ),
                    if (_error != null)
                      Text(
                        translatedMessage(context, _error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    StudyButton(
                      tr(context, "حفظ تفاصيل المادة"),
                      _picking
                          ? null
                          : () {
                              if (!_form.currentState!.validate()) return;
                              Navigator.pop(
                                context,
                                StudySubject(
                                  _name.text.trim(),
                                  widget.subject.exam,
                                  widget.subject.parts,
                                  id: widget.subject.id,
                                  pdfName: _pdf,
                                  nextPartId: widget.subject.nextPartId,
                                ),
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
