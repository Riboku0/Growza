import 'email_validation.dart';
import 'account_service.dart';
import 'password_hash.dart';

import 'package:flutter/material.dart';

import 'study_ui.dart';
import 'form_guard.dart';

/// Local account by default: no email verification or network dependency.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.createAccount = false,
    this.onGuest,
    this.onAuthenticated,
  });
  final bool createAccount;
  final VoidCallback? onGuest;
  final VoidCallback? onAuthenticated;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { signIn, create, reset }

class _AuthScreenState extends State<AuthScreen> {
  var _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late _AuthMode _mode = widget.createAccount
      ? _AuthMode.create
      : _AuthMode.signIn;
  bool _obscure = true;
  String? _notice;
  bool _busy = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _change(_AuthMode mode) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _notice = null;
      _password.clear();
      _confirmation.clear();
      _form = GlobalKey<FormState>();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    FocusScope.of(context).unfocus();
    final account = AccountScope.maybeOf(context);
    if (account == null || !account.configured) {
      setState(
        () => _notice =
            'الحسابات غير متاحة حالياً. يمكنك متابعة المذاكرة دون حساب.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      if (_mode == _AuthMode.reset) {
        await account.recover(_email.text);
        if (mounted) {
          setState(
            () => _notice = 'إذا كان البريد مسجلاً فستصلك رسالة الاستعادة.',
          );
        }
      } else {
        final signedIn = _mode == _AuthMode.create
            ? await account.create(_email.text, _password.text)
            : await (() async {
                await account.signIn(_email.text, _password.text);
                return true;
              })();
        if (!mounted) return;
        if (signedIn) {
          _password.clear();
          _confirmation.clear();
          if (widget.onAuthenticated != null) {
            widget.onAuthenticated!();
          } else {
            Navigator.pop(context);
          }
        } else {
          setState(() => _notice = accountMessage('email_confirmation'));
        }
      }
    } on AccountException catch (e) {
      if (mounted) setState(() => _notice = accountMessage(e.code));
    } catch (_) {
      if (mounted) setState(() => _notice = accountMessage('unavailable'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AccountScope.maybeOf(context)?.isLocal ?? true;
    final title = switch (_mode) {
      _AuthMode.signIn => tr(context, 'تسجيل الدخول'),
      _AuthMode.create => tr(context, 'إنشاء حساب'),
      _AuthMode.reset => tr(context, 'استعادة كلمة المرور'),
    };
    return ConfirmDiscard(
      dirty: _password.text.isNotEmpty || _confirmation.text.isNotEmpty,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: ScreenList(
            controller: _scroll,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Image.asset(
                  'assets/branding/growza-icon.png',
                  width: 64,
                  height: 64,
                  excludeFromSemantics: true,
                ),
              ),
              PageHeading(title, tr(context, 'تقدمك يبدأ بخطوة صغيرة.')),
              if (_busy) const LinearProgressIndicator(),
              Form(
                key: _form,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    TextFormField(
                      key: const ValueKey('auth-email'),
                      controller: _email,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      textInputAction: _mode == _AuthMode.reset
                          ? TextInputAction.done
                          : TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: tr(context, 'البريد الإلكتروني'),
                        hintText: 'you@example.com',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) => isValidAccountEmail(value ?? '')
                          ? null
                          : tr(context, 'أدخل بريداً إلكترونياً صحيحاً.'),
                    ),
                    if (_mode != _AuthMode.reset)
                      TextFormField(
                        key: const ValueKey('auth-password'),
                        controller: _password,
                        obscureText: _obscure,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: [
                          _mode == _AuthMode.create
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: _mode == _AuthMode.create
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_mode == _AuthMode.signIn) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: tr(context, 'كلمة المرور'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: tr(
                              context,
                              _obscure
                                  ? 'إظهار كلمة المرور'
                                  : 'إخفاء كلمة المرور',
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return tr(context, 'أدخل كلمة المرور.');
                          }
                          if (_mode == _AuthMode.create) {
                            if (value.length <
                                LocalAuthRules.minPasswordCharacters) {
                              return tr(context, 'استخدم 8 أحرف على الأقل.');
                            }
                            if (value.length >
                                LocalAuthRules.maxPasswordCharacters) {
                              return tr(
                                context,
                                accountMessage('weak_password'),
                              );
                            }
                          }
                          return null;
                        },
                      ),
                    if (_mode == _AuthMode.create)
                      TextFormField(
                        key: const ValueKey('auth-confirmation'),
                        controller: _confirmation,
                        obscureText: _obscure,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: tr(context, 'تأكيد كلمة المرور'),
                        ),
                        validator: (value) => value == _password.text
                            ? null
                            : tr(context, 'كلمتا المرور غير متطابقتين.'),
                      ),
                    if (_mode == _AuthMode.signIn && !local)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: const ValueKey('auth-reset'),
                          onPressed: () => _change(_AuthMode.reset),
                          child: Text(tr(context, 'نسيت كلمة المرور؟')),
                        ),
                      ),
                    if (_notice != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          tr(context, _notice!),
                          key: const ValueKey('auth-notice'),
                          style: TextStyle(
                            color: GrowzaPalette.of(context).warningText,
                          ),
                        ),
                      ),
                    StudyButton(
                      _mode == _AuthMode.reset
                          ? tr(context, 'إرسال رابط الاستعادة')
                          : title,
                      _busy ? null : _submit,
                      key: const ValueKey('auth-submit'),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('auth-switch'),
                onPressed: () => _change(
                  _mode == _AuthMode.create
                      ? _AuthMode.signIn
                      : _AuthMode.create,
                ),
                child: Text(
                  tr(
                    context,
                    _mode == _AuthMode.create
                        ? 'لديك حساب؟ سجّل الدخول'
                        : 'ليس لديك حساب؟ أنشئ حساباً',
                  ),
                ),
              ),
              if (_mode == _AuthMode.reset)
                TextButton(
                  onPressed: () => _change(_AuthMode.signIn),
                  child: Text(tr(context, 'العودة لتسجيل الدخول')),
                ),
              TextButton(
                onPressed: widget.onGuest ?? () => Navigator.maybePop(context),
                child: Text(tr(context, 'متابعة دون حساب')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
