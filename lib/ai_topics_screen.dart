import 'package:flutter/material.dart';

import 'form_guard.dart';
import 'pdf_topics.dart';
import 'pdf_topic_import.dart';
import 'study_ui.dart';

Future<PdfTopicDraft?> showAiTopics(
  BuildContext context, {
  required String subject,
  String? pdfName,
  List<String> existingTitles = const [],
}) => Navigator.of(context).push<PdfTopicDraft>(
  GrowzaRoute(
    builder: (_) => AiTopicsScreen(
      subject: subject,
      pdfName: pdfName,
      existingTitles: existingTitles,
    ),
  ),
);

class AiTopicsScreen extends StatefulWidget {
  const AiTopicsScreen({
    super.key,
    required this.subject,
    this.pdfName,
    this.provider,
    this.pick,
    this.existingTitles = const [],
  });
  final String subject;
  final String? pdfName;
  final TopicProvider? provider;
  final Future<PdfHeadings?> Function()? pick;
  final List<String> existingTitles;
  @override
  State<AiTopicsScreen> createState() => _AiTopicsScreenState();
}

class _AiTopicsScreenState extends State<AiTopicsScreen> {
  PdfTopicDraft? _draft;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => ConfirmDiscard(
    dirty: _draft != null,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'اقترح المواضيع من الملف'))),
      body: SafeArea(
        child: ScreenList(
          children: [
            Text(widget.subject, style: Theme.of(context).textTheme.titleLarge),
            PdfTopicImport(
              pdfName: widget.pdfName,
              provider: widget.provider,
              existingTitles: widget.existingTitles,
              pick: widget.pick == null
                  ? null
                  : () async {
                      final doc = await widget.pick!();
                      return doc == null
                          ? null
                          : StudyPdfSelection(
                              widget.pdfName ?? 'study.pdf',
                              doc,
                            );
                    },
              onChanged: (draft) => setState(() => _draft = draft),
              onBusyChanged: (busy) => setState(() => _busy = busy),
            ),
            if (_draft?.hasTopics == true)
              StudyButton(
                tr(context, 'تأكيد إضافة المواضيع'),
                _busy || !_draft!.valid
                    ? null
                    : () => Navigator.pop(context, _draft),
                key: const ValueKey('ai-confirm'),
              ),
          ],
        ),
      ),
    ),
  );
}
