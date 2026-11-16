import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import 'study_ui.dart';
import 'study_storage.dart';
import 'workspace_backup.dart';
import 'backup_files.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.snapshot,
    required this.onApply,
    required this.canImport,
  });
  final Future<StudyWorkspace> Function() snapshot;
  final Future<void> Function(StudyWorkspace) onApply;
  final bool Function() canImport;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _message;
  StudyWorkspace? _incoming;
  bool _replace = false;
  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final current = await widget.snapshot();
      final text = WorkspaceBackup.export(current);
      final ok = await saveBackupFile(
        text,
        'Growza-backup-${DateTime.now().toIso8601String().split('T').first}.json',
      );
      if (mounted) {
        setState(
          () => _message = ok ? 'حُفظت النسخة الاحتياطية.' : 'أُلغي الحفظ.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'تعذّر حفظ النسخة الاحتياطية. حاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    if (!widget.canImport()) {
      setState(
        () => _message = 'أنهِ المؤقت الحالي قبل استيراد نسخة احتياطية.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Growza backup',
            extensions: ['json'],
            mimeTypes: ['application/json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > WorkspaceBackup.maxBytes) {
        throw const BackupException('حجم النسخة الاحتياطية أكبر من المسموح.');
      }
      final result = WorkspaceBackup.parse(
        utf8.decode(await file.readAsBytes()),
      );
      if (mounted) {
        setState(() {
          _incoming = result;
          _message = null;
        });
      }
    } on BackupException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'تعذّرت قراءة النسخة الاحتياطية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    if (_incoming == null || !widget.canImport()) {
      setState(
        () => _message = 'أنهِ المؤقت الحالي قبل استيراد نسخة احتياطية.',
      );
      return;
    }
    if (_busy) return;
    StudyWorkspace result;
    try {
      final current = await widget.snapshot();
      result = _replace
          ? _incoming!
          : WorkspaceBackup.merge(current, _incoming!);
      result.backupReplaceCalendars = _replace;
    } on BackupException catch (e) {
      if (mounted) setState(() => _message = e.message);
      return;
    } catch (_) {
      if (mounted) setState(() => _message = 'تعذّرت قراءة النسخة الاحتياطية.');
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr(
            context,
            _replace ? 'استبدال بيانات هذا الجهاز؟' : 'دمج النسخة الاحتياطية؟',
          ),
        ),
        content: Text(
          tr(
            context,
            _replace
                ? 'سيُستبدل سجل المذاكرة الحالي بمحتوى الملف. تأكد من حفظ نسخة حالية أولاً.'
                : 'ستُضاف العناصر الناقصة. تبقى البيانات الحالية عند التعارض، وقد تعود عناصر حُذفت سابقاً.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'تأكيد الاستيراد')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onApply(result);
      if (mounted) {
        setState(() {
          _incoming = null;
          _message = 'اكتمل استيراد النسخة الاحتياطية.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'تعذّر استيراد النسخة. بقيت بياناتك الحالية محفوظة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'النسخ الاحتياطي'))),
    body: SafeArea(
      child: ScreenList(
        children: [
          PageHeading(
            tr(context, 'نسخة من تقدمك'),
            tr(
              context,
              'احفظ موادك ومواضيعك وجلساتك وتقاويمك وإعداداتك في ملف على جهازك.',
            ),
          ),
          Text(
            tr(
              context,
              'لا يتضمن الملف كلمات مرور أو رموز دخول. احتفظ به في مكان تختاره بعناية.',
            ),
          ),
          StudyButton(
            tr(context, 'تصدير نسخة احتياطية'),
            _busy ? null : _export,
            key: const ValueKey('backup-export'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _pick,
            key: const ValueKey('backup-pick'),
            child: Text(tr(context, 'اختيار نسخة للاستيراد')),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_incoming case final incoming?) ...[
            Text(
              tr(context, 'المواد: {0} · سجلات التركيز: {1}', [
                incoming.subjects.length,
                incoming.growth.records.length,
              ]),
            ),
            RadioGroup<bool>(
              groupValue: _replace,
              onChanged: (value) => setState(() => _replace = value!),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: false,
                    title: Text(tr(context, 'دمج مع البيانات الحالية')),
                  ),
                  RadioListTile<bool>(
                    value: true,
                    title: Text(tr(context, 'استبدال البيانات الحالية')),
                  ),
                ],
              ),
            ),
            StudyButton(
              tr(context, 'مراجعة الاستيراد'),
              _busy ? null : _apply,
              key: const ValueKey('backup-apply'),
            ),
          ],
          if (_message != null)
            Semantics(
              liveRegion: true,
              child: Text(
                tr(context, _message!),
                key: const ValueKey('backup-message'),
              ),
            ),
        ],
      ),
    ),
  );
}
