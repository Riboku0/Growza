import 'package:flutter/material.dart';

import 'account_service.dart';
import 'study_ui.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _busy = false;
  String? _message;
  Future<void> _delete() async {
    final account = AccountScope.maybeOf(context);
    if (account?.session == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'حذف حسابي')),
        content: Text(
          tr(
            context,
            account!.isLocal
                ? 'سيُحذف البريد وبصمة كلمة المرور من هذا الجهاز. تبقى موادك وجلساتك محفوظة. هل تريد المتابعة؟'
                : 'سيُحذف حساب الدخول من الخدمة. تبقى بيانات المذاكرة على هذا الجهاز؛ لا توجد مزامنة سحابية حالياً. هل تريد المتابعة؟',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'حذف الحساب')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await account!.deleteAccount();
      if (mounted) {
        setState(() => _message = 'حُذف حسابك. يمكنك الاستمرار دون حساب.');
      }
    } on AccountException catch (e) {
      if (mounted) setState(() => _message = accountMessage(e.code));
    } catch (_) {
      if (mounted) setState(() => _message = accountMessage('unavailable'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'الخصوصية والحساب'))),
    body: SafeArea(
      child: ScreenList(
        children: [
          Text(
            tr(
              context,
              'موادك ومواضيعك وجلساتك وإعداداتك محفوظة على جهازك. لا توجد مزامنة سحابية في هذه النسخة.',
            ),
          ),
          Text(
            tr(
              context,
              AccountScope.maybeOf(context)?.isLocal != false
                  ? 'الحساب محلي واختياري. نحفظ بريدك وبصمة كلمة المرور على هذا الجهاز دون إرسالها. لا يوجد تحقق أو استعادة بالبريد.'
                  : 'الحساب اختياري. يُرسل البريد وكلمة المرور لخدمة الحساب عند طلب الدخول، ولا نحفظ كلمة المرور. تُحفظ رموز الدخول في مخزن الجهاز الآمن.',
            ),
          ),
          Text(
            tr(
              context,
              'اقتراح المواضيع يرسل نص الفهرس فقط بعد موافقتك؛ لا يُرسل ملف PDF. راجع النص قبل الإرسال.',
            ),
          ),
          Text(
            tr(
              context,
              'قد يتضمن رابط التقويم مفتاحاً خاصاً للوصول. لا تشارك رابطك أو ملف النسخة الاحتياطية مع الآخرين.',
            ),
          ),
          Text(
            tr(
              context,
              'الحساب المحلي لا ينشئ مساحة مواد منفصلة. متابعة دون حساب تعرض بيانات الدراسة نفسها على هذا الجهاز.',
            ),
          ),
          if (AccountScope.maybeOf(context)?.session != null)
            OutlinedButton(
              onPressed: _busy ? null : _delete,
              child: Text(tr(context, 'حذف حسابي')),
            ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_message != null) Text(tr(context, _message!)),
        ],
      ),
    ),
  );
}
