import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'account_service.dart';
import 'growth_rules.dart';
import 'pdf_topics.dart';
import 'study_data.dart';
import 'study_input.dart';
import 'study_ui.dart';

class StudyPdfSelection {
  const StudyPdfSelection(this.name, this.document);
  final String name;
  final PdfHeadings document;
}

typedef StudyPdfPicker = Future<StudyPdfSelection?> Function();

Future<StudyPdfSelection?> pickStudyPdf() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      ),
    ],
  );
  if (file == null) return null;
  if (!file.name.toLowerCase().endsWith('.pdf')) {
    throw const AccountException('pdf_type');
  }
  if (await file.length() > GrowthRules.pdfMaxBytes) {
    throw const AccountException('pdf_large');
  }
  return StudyPdfSelection(
    file.name,
    await extractPdfHeadings(await file.readAsBytes()),
  );
}

String topicTitleKey(String title) =>
    title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

List<SuggestedTopic> uniquePdfTopics(
  Iterable<SuggestedTopic> topics, {
  Iterable<String> existingTitles = const [],
}) {
  final seen = existingTitles.map(topicTitleKey).toSet();
  return [
    for (final topic in topics)
      if (seen.add(topicTitleKey(topic.title))) topic,
  ];
}

class PdfTopicDraft {
  PdfTopicDraft(this.fileName, Iterable<SuggestedTopic> topics)
    : topics = List.unmodifiable(topics);
  final String fileName;
  final List<SuggestedTopic> topics;
  bool get hasTopics => topics.isNotEmpty;
  bool get valid =>
      topics.every((t) => t.minutes <= GrowthRules.pdfMaxTopicMinutes);
}

StudySubject appendPdfTopics(
  StudySubject subject,
  PdfTopicDraft draft, {
  bool updateReference = false,
}) {
  if (!draft.valid) {
    throw const FormatException('Topic exceeds study duration limit');
  }
  var next = subject.nextPartId;
  final added = uniquePdfTopics(
    draft.topics,
    existingTitles: subject.parts.map((p) => p.title),
  );
  return StudySubject(
    subject.name,
    subject.exam,
    [
      for (final part in subject.parts)
        part.pdfName == null &&
                part.startPage != null &&
                subject.pdfName != null
            ? part.withPdfReference(subject.pdfName)
            : part,
      for (final topic in added)
        StudyPart(
          next++,
          topic.title,
          topic.minutes,
          startPage: topic.startPage,
          endPage: topic.endPage,
          pdfName: draft.fileName,
        ),
    ],
    id: subject.id,
    nextPartId: next,
    pdfName: updateReference
        ? draft.fileName
        : subject.pdfName ?? draft.fileName,
  );
}

/// The same import/review flow is embedded in creation, editing and the shortcut.
/// Picking reads locally; a request is made only after the explicit preview consent.
class PdfTopicImport extends StatefulWidget {
  const PdfTopicImport({
    super.key,
    required this.onChanged,
    this.onBusyChanged,
    this.pdfName,
    this.provider,
    this.pick,
    this.existingTitles = const [],
  });
  final ValueChanged<PdfTopicDraft?> onChanged;
  final ValueChanged<bool>? onBusyChanged;
  final String? pdfName;
  final TopicProvider? provider;
  final StudyPdfPicker? pick;
  final List<String> existingTitles;
  @override
  State<PdfTopicImport> createState() => _PdfTopicImportState();
}

class _PdfTopicImportState extends State<PdfTopicImport> {
  PdfHeadings? _document;
  String? _fileName, _message;
  bool _busy = false, _analysing = false, _removed = false, _consenting = false;
  int _skipped = 0;
  List<SuggestedTopic> _topics = [];
  bool get _configured =>
      widget.provider != null ||
      AccountScope.maybeOf(context)?.aiConfigured == true;
  String? get _name => _fileName ?? (_removed ? null : widget.pdfName);

  void _emit() =>
      widget.onChanged(_name == null ? null : PdfTopicDraft(_name!, _topics));
  void _setBusy(bool value, {bool analysing = false, bool consenting = false}) {
    if (!mounted) return;
    setState(() {
      _busy = value;
      _analysing = analysing;
      _consenting = consenting;
    });
    widget.onBusyChanged?.call(value);
  }

  Future<void> _choose() async {
    if (_busy) return;
    _setBusy(true);
    StudyPdfSelection? selection;
    try {
      selection = await (widget.pick ?? pickStudyPdf)();
      if (!mounted || selection == null) return;
      setState(() {
        _document = selection!.document;
        _fileName = selection.name;
        _removed = false;
        _topics = [];
        _message = null;
        _skipped = 0;
      });
      _emit();
    } on AccountException catch (e) {
      if (mounted) setState(() => _message = pdfImportMessage(e.code));
    } catch (_) {
      if (mounted) setState(() => _message = pdfImportMessage('pdf_no_text'));
    } finally {
      _setBusy(false);
    }
    if (selection != null && mounted) await _suggest();
  }

  Future<void> _suggest() async {
    final document = _document;
    if (document == null || _busy) return;
    if (!_configured) {
      setState(() => _message = accountMessage('unavailable'));
      return;
    }
    // Disable conflicting actions while awaiting a decision, without an idle spinner.
    _setBusy(true, consenting: true);
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr(context, 'قبل الإرسال')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(
                      context,
                      'سيُرسل نص الفهرس المعروض إلى Cloudflare Workers AI بعد موافقتك. لن يُرسل ملف PDF نفسه أو بريدك أو كلمة مرورك. راجع النص قبل الإرسال.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(tr(context, 'عدد الصفحات: {0}', [document.pageCount])),
                  if (document.truncated)
                    Text(
                      tr(
                        context,
                        'هذه معاينة محدودة من الفهرس؛ قد لا تشمل كل الصفحات.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  SelectableText(
                    document.text,
                    key: const ValueKey('pdf-consent-preview'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr(context, 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr(context, 'أوافق وأرسل')),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      setState(() {
        _analysing = true;
        _consenting = false;
        _message = null;
      });
      final accounts = AccountScope.maybeOf(context);
      final provider =
          widget.provider ??
          (accounts == null ? null : WorkerTopicProvider(accounts));
      if (provider == null) throw const AccountException('unavailable');
      final response = await provider.suggest(document);
      final validated = SuggestedTopic.parse(
        response.map((t) => t.toJson()).toList(),
        document.pageCount,
      );
      if (!mounted) return;
      final topics = uniquePdfTopics(
        validated,
        existingTitles: widget.existingTitles,
      );
      setState(() {
        _topics = topics;
        _skipped = validated.length - topics.length;
        _message = topics.isEmpty
            ? 'مواضيع هذا الملف موجودة بالفعل. لم تُضف نسخ مكررة.'
            : null;
      });
      _emit();
    } on AccountException catch (e) {
      if (mounted) setState(() => _message = pdfImportMessage(e.code));
    } catch (_) {
      if (mounted) setState(() => _message = pdfImportMessage('unavailable'));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _edit([int? index]) async {
    final old = index == null ? null : _topics[index];
    final title = TextEditingController(text: old?.title ?? '');
    final start = TextEditingController(text: '${old?.startPage ?? 1}');
    final end = TextEditingController(text: '${old?.endPage ?? 1}');
    final form = GlobalKey<FormState>();
    final result = await showDialog<SuggestedTopic>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'الموضوع')),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  maxLength: GrowthRules.pdfMaxTitleCharacters,
                  decoration: InputDecoration(
                    labelText: tr(context, 'عنوان الموضوع'),
                  ),
                  validator: (s) {
                    if (s == null ||
                        s.trim().isEmpty ||
                        RegExp(
                          r'https?:|www\.|<[^>]+>',
                          caseSensitive: false,
                        ).hasMatch(s)) {
                      return tr(context, 'أدخل عنواناً قصيراً دون روابط.');
                    }
                    final names = [
                      ...widget.existingTitles,
                      for (final (i, t) in _topics.indexed)
                        if (i != index) t.title,
                    ];
                    return names.any(
                          (n) => topicTitleKey(n) == topicTitleKey(s),
                        )
                        ? tr(context, 'يوجد موضوع بهذا الاسم بالفعل.')
                        : null;
                  },
                ),
                TextFormField(
                  controller: start,
                  keyboardType: TextInputType.number,
                  inputFormatters: [studyDigitsFormatter],
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr(context, 'من صفحة'),
                  ),
                  validator: (s) {
                    final n = int.tryParse(s ?? '');
                    return n == null || n < 1 || n > _document!.pageCount
                        ? tr(context, 'تحقّق من نطاق الصفحات.')
                        : null;
                  },
                ),
                TextFormField(
                  controller: end,
                  keyboardType: TextInputType.number,
                  inputFormatters: [studyDigitsFormatter],
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr(context, 'إلى صفحة'),
                  ),
                  validator: (s) {
                    final n = int.tryParse(s ?? ''),
                        a = int.tryParse(start.text);
                    return n == null ||
                            a == null ||
                            n < a ||
                            n > _document!.pageCount ||
                            (n - a + 1) * GrowthRules.pdfMinutesPerPage >
                                GrowthRules.pdfMaxTopicMinutes
                        ? tr(
                            context,
                            'تحقّق من الصفحات؛ الحد الأقصى للموضوع 720 دقيقة.',
                          )
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr(context, 'إلغاء')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  dialogContext,
                  SuggestedTopic(
                    title.text.trim(),
                    int.parse(start.text),
                    int.parse(end.text),
                  ),
                );
              }
            },
            child: Text(tr(context, 'حفظ')),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    start.dispose();
    end.dispose();
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          _topics.add(result);
        } else {
          _topics[index] = result;
        }
      });
      _emit();
    }
  }

  void _remove() {
    setState(() {
      _document = null;
      _fileName = null;
      _removed = true;
      _topics = [];
      _message = null;
      _skipped = 0;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        tr(context, 'مواضيع من PDF · اختياري'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 6),
      Text(
        tr(
          context,
          'اختر ملف المادة أو الشابتر؛ نقرأ الفهرس هنا ثم نقترح مواضيع بعد موافقتك. راجعها قبل الحفظ.',
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: const ValueKey('ai-pick'),
          onPressed: _busy ? null : _choose,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            tr(context, _name == null ? 'اختر ملف PDF' : 'تغيير ملف PDF'),
          ),
        ),
      ),
      if (_name case final name?) ...[
        Text(
          name,
          textDirection: TextDirection.ltr,
          key: const ValueKey('pdf-file-name'),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _busy ? null : _remove,
            child: Text(tr(context, 'إزالة مرجع PDF')),
          ),
        ),
      ],
      if (_busy && !_consenting)
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    context,
                    _analysing ? 'جارٍ اقتراح المواضيع…' : 'جارٍ قراءة الملف…',
                  ),
                ),
              ),
            ],
          ),
        ),
      if (_message != null || !_configured)
        Semantics(
          liveRegion: true,
          child: Text(
            tr(context, _message ?? accountMessage('unavailable')),
            key: const ValueKey('ai-unavailable'),
          ),
        ),
      if (_skipped > 0 && _topics.isNotEmpty)
        Text(tr(context, 'تجاوزنا {0} مواضيع مكررة.', [_skipped])),
      if (_document != null && _topics.isEmpty && !_busy)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('ai-send'),
            onPressed: _suggest,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(tr(context, 'تحليل الملف بالذكاء الاصطناعي')),
          ),
        ),
      if (_topics.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          tr(context, 'راجع المواضيع قبل إضافتها'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final (i, topic) in _topics.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(topic.title),
            subtitle: Text(
              tr(context, 'صفحات {0}–{1} · {2} دقيقة', [
                topic.startPage,
                topic.endPage,
                topic.minutes,
              ]),
            ),
            onTap: _busy ? null : () => _edit(i),
            trailing: IconButton(
              tooltip: tr(context, 'حذف'),
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _topics.removeAt(i));
                      _emit();
                    },
              icon: const Icon(Icons.close),
            ),
          ),
        if (_topics.any((t) => t.minutes > GrowthRules.pdfMaxTopicMinutes))
          Text(
            tr(
              context,
              'بعض المواضيع طويلة جداً. قسّمها إلى مواضيع أصغر قبل الحفظ.',
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _busy || _topics.length >= GrowthRules.pdfMaxTopics
                ? null
                : () => _edit(),
            child: Text(tr(context, 'إضافة موضوع')),
          ),
        ),
      ],
    ],
  );
}

String pdfImportMessage(String code) => switch (code) {
  'pdf_type' => 'اختر ملف PDF.',
  'pdf_large' => 'حجم الملف أو عدد صفحاته أكبر من المسموح. اختر ملفاً أصغر.',
  'pdf_no_text' => 'هذا الملف لا يمكن تحليله، أضف المواضيع يدوياً.',
  _ => accountMessage(code),
};
