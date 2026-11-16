import 'study_input.dart';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'account_service.dart';
import 'form_guard.dart';
import 'growth_rules.dart';
import 'pdf_topics.dart';
import 'study_ui.dart';

Future<List<SuggestedTopic>?> showAiTopics(
  BuildContext context, {
  required String subject,
  String? pdfName,
}) => Navigator.of(context).push<List<SuggestedTopic>>(
  GrowzaRoute(
    builder: (_) => AiTopicsScreen(subject: subject, pdfName: pdfName),
  ),
);

class AiTopicsScreen extends StatefulWidget {
  const AiTopicsScreen({
    super.key,
    required this.subject,
    this.pdfName,
    this.provider,
    this.pick,
  });
  final String subject;
  final String? pdfName;
  final TopicProvider? provider;
  final Future<PdfHeadings?> Function()? pick;
  @override
  State<AiTopicsScreen> createState() => _AiTopicsScreenState();
}

class _AiTopicsScreenState extends State<AiTopicsScreen> {
  PdfHeadings? _document;
  String? _fileName, _message;
  bool _busy = false, _demo = false;
  List<SuggestedTopic> _topics = [];
  Future<void> _choose() async {
    setState(() => _busy = true);
    try {
      PdfHeadings? document;
      if (widget.pick != null) {
        document = await widget.pick!();
      } else {
        final file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'PDF',
              extensions: ['pdf'],
              mimeTypes: ['application/pdf'],
              uniformTypeIdentifiers: ['com.adobe.pdf'],
            ),
          ],
        );
        if (file == null) return;
        if (await file.length() > GrowthRules.pdfMaxBytes) {
          throw const AccountException('pdf_large');
        }
        document = await extractPdfHeadings(await file.readAsBytes());
        _fileName = file.name;
      }
      if (document == null) return;
      if (mounted) {
        setState(() {
          _document = document;
          _topics = [];
          _message = null;
        });
      }
    } on AccountException catch (e) {
      if (mounted) setState(() => _message = pdfMessage(e.code));
    } catch (_) {
      if (mounted) setState(() => _message = pdfMessage('pdf_no_text'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _suggest() async {
    final document = _document;
    if (document == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'قبل الإرسال')),
        content: Text(
          tr(
            context,
            'سيُرسل نص الفهرس المعروض إلى Cloudflare Workers AI بعد موافقتك. لن يُرسل ملف PDF نفسه أو بريدك أو كلمة مرورك. راجع النص قبل الإرسال.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'أوافق وأرسل')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final accounts = AccountScope.maybeOf(context);
      final provider =
          widget.provider ??
          (accounts == null ? null : WorkerTopicProvider(accounts));
      if (provider == null) throw const AccountException('unavailable');
      final topics = await provider.suggest(document);
      if (mounted) {
        setState(() {
          _topics = topics;
          _message = null;
          _demo = false;
        });
      }
    } on AccountException catch (e) {
      _failed(e.code, document);
    } catch (_) {
      _failed('unavailable', document);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _failed(String code, PdfHeadings document) {
    if (!mounted) return;
    setState(() {
      _message = pdfMessage(code);
      if (const bool.fromEnvironment('GROWZA_AI_DEMO')) {
        _demo = true;
        _topics = [
          SuggestedTopic('Demo topic', 1, document.pageCount.clamp(1, 5)),
        ];
      }
    });
  }

  Future<void> _edit([int? index]) async {
    final old = index == null ? null : _topics[index];
    final title = TextEditingController(text: old?.title ?? '');
    final start = TextEditingController(text: '${old?.startPage ?? 1}');
    final end = TextEditingController(text: '${old?.endPage ?? 1}');
    final form = GlobalKey<FormState>();
    final result = await showDialog<SuggestedTopic>(
      context: context,
      builder: (context) => AlertDialog(
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
                  validator: (s) =>
                      s == null ||
                          s.trim().isEmpty ||
                          RegExp(
                            r'https?:|www\.|<[^>]+>',
                            caseSensitive: false,
                          ).hasMatch(s)
                      ? tr(context, 'أدخل عنواناً قصيراً دون روابط.')
                      : null,
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
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'إلغاء')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
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
    // Controllers outlive the closing dialog animation.
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
    }
  }

  @override
  Widget build(BuildContext context) => ConfirmDiscard(
    dirty: _topics.isNotEmpty,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'اقترح المواضيع من الملف'))),
      body: SafeArea(
        child: ScreenList(
          children: [
            Text(widget.subject, style: Theme.of(context).textTheme.titleLarge),
            Text(tr(context, 'مساعدة اختيارية، وخطتك تبقى بيدك.')),
            if (_document == null)
              Text(
                tr(
                  context,
                  'لم يُرسل أي ملف أو نص. سيُطلب إذنك قبل استخدام الخدمة.',
                ),
              ),
            if (_message == null &&
                widget.provider == null &&
                AccountScope.maybeOf(context)?.aiConfigured != true)
              Text(
                tr(context, accountMessage('unavailable')),
                key: const ValueKey('ai-unavailable'),
              ),
            Text(
              tr(
                context,
                'يُقرأ الفهرس على جهازك أولاً. راجع النص والعناوين، خصوصاً الملفات العربية، قبل الإرسال.',
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('ai-pick'),
              onPressed: _busy ? null : _choose,
              icon: const Icon(Icons.attach_file),
              label: Text(tr(context, 'اختر ملف PDF')),
            ),
            if (_fileName ?? widget.pdfName case final name?)
              Text(name, textDirection: TextDirection.ltr),
            if (_document case final document?) ...[
              Text(tr(context, 'عدد الصفحات: {0}', [document.pageCount])),
              if (document.truncated)
                Text(
                  tr(
                    context,
                    'هذه معاينة محدودة من الفهرس؛ قد لا تشمل كل الصفحات.',
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: SelectableText(document.text),
                ),
              ),
              StudyButton(
                tr(context, 'مراجعة الموافقة والإرسال'),
                _busy ? null : _suggest,
                key: const ValueKey('ai-send'),
              ),
            ],
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_message != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  tr(context, _message!),
                  key: const ValueKey('ai-unavailable'),
                ),
              ),
            if (_demo)
              Text(
                tr(
                  context,
                  'وضع العرض: هذه نتيجة تجريبية وليست تحليلاً للملف.',
                ),
              ),
            if (_topics.any((t) => t.minutes > GrowthRules.pdfMaxTopicMinutes))
              Text(
                tr(
                  context,
                  'بعض المواضيع طويلة جداً. قسّمها إلى مواضيع أصغر قبل الحفظ.',
                ),
              ),
            if (_topics.isNotEmpty) ...[
              Text(tr(context, 'راجع المواضيع قبل إضافتها')),
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
                        : () => setState(() => _topics.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              TextButton(
                onPressed: _busy || _topics.length >= GrowthRules.pdfMaxTopics
                    ? null
                    : () => _edit(),
                child: Text(tr(context, 'إضافة موضوع')),
              ),
              StudyButton(
                tr(context, 'تأكيد إضافة المواضيع'),
                _busy ||
                        _topics.any(
                          (t) => t.minutes > GrowthRules.pdfMaxTopicMinutes,
                        )
                    ? null
                    : () => Navigator.pop(context, _topics),
                key: const ValueKey('ai-confirm'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String pdfMessage(String code) => switch (code) {
  'pdf_large' => 'حجم الملف أو عدد صفحاته أكبر من المسموح. اختر ملفاً أصغر.',
  'pdf_no_text' => 'هذا الملف لا يمكن تحليله، أضف المواضيع يدوياً.',
  _ => accountMessage(code),
};
