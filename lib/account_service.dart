import 'account_models.dart';
import 'local_account_store.dart';
export 'account_models.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'secure_storage.dart';
import 'worker_ai_service.dart';
export 'secure_storage.dart';

class AccountService extends ChangeNotifier {
  AccountService({
    http.Client? client,
    SessionVault? vault,
    SessionVault? installationVault,
    String? workerUrl,
    bool local = true,
    LocalAccounts? localAccounts,
  }) : isLocal = local,
       _localAccounts = localAccounts ?? LocalAccountStore(),
       _ownsLocalAccounts = localAccounts == null,
       _client = client ?? http.Client(),
       _vault =
           vault ??
           SecureSessionVault(
             key: local
                 ? 'growza.local-account.session'
                 : 'growza.account.session',
           ) {
    final raw = workerUrl ?? const String.fromEnvironment('GROWZA_WORKER_URL');
    final parsed = Uri.tryParse(raw);
    if (parsed != null &&
        parsed.host.isNotEmpty &&
        parsed.userInfo.isEmpty &&
        !parsed.hasQuery &&
        !parsed.hasFragment &&
        (parsed.scheme == 'https' ||
            (kDebugMode &&
                parsed.scheme == 'http' &&
                [
                  'localhost',
                  '127.0.0.1',
                  '10.0.2.2',
                ].contains(parsed.host)))) {
      _base = parsed;
    }
    _workerAi = WorkerAiService(
      client: _client,
      base: _base,
      vault:
          installationVault ??
          const SecureSessionVault(key: 'growza.worker.installation'),
    );
  }
  final bool isLocal;
  final LocalAccounts _localAccounts;
  final bool _ownsLocalAccounts;
  final http.Client _client;
  final SessionVault _vault;
  Uri? _base;
  late final WorkerAiService _workerAi;
  AccountSession? session;
  bool get configured => isLocal ? !kIsWeb : _base != null;
  bool get cloudConfigured => !isLocal && _base != null;
  bool get aiConfigured => _base != null;
  bool _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<Map<String, dynamic>> request(
    String path,
    Map<String, dynamic> data, {
    String? token,
    String method = 'POST',
  }) async {
    if (!cloudConfigured) throw const AccountException('unavailable');
    try {
      final request =
          http.Request(
              method,
              _base!.replace(
                path: '${_base!.path.replaceAll(RegExp(r'/$'), '')}$path',
              ),
            )
            ..followRedirects = false
            ..headers.addAll({
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            })
            ..body = jsonEncode(data);
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 25));
      final bytes = <int>[];
      await for (final chunk in streamed.stream.timeout(
        const Duration(seconds: 25),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 256 * 1024) {
          throw const AccountException('invalid_response');
        }
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map) throw const FormatException();
      final result = Map<String, dynamic>.from(value);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw AccountException(
          result['code'] is String ? result['code'] as String : 'unavailable',
        );
      }
      return result;
    } on AccountException {
      rethrow;
    } on FormatException {
      throw const AccountException('invalid_response');
    } on TimeoutException {
      throw const AccountException('network');
    } catch (_) {
      throw const AccountException('network');
    }
  }

  Future<void>? _restoring;
  Future<void> restore() => _restoring ??= _restore();
  Future<void> _restore() async {
    if (!configured) return;
    try {
      final raw = await _vault.read();
      if (raw == null) return;
      final saved = AccountSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (isLocal) {
        if (!saved.isLocal) return;
        final user = await _localAccounts.find(saved.userId);
        if (user != null && user.email == saved.email) {
          session = saved;
        } else {
          await _vault.clear();
        }
        _changed();
        return;
      }
      if (saved.isLocal) return;
      // Offline launch retains the local session; AI validates it before any use.
      try {
        session = AccountSession.fromJson(
          await request('/auth/refresh', {'refresh_token': saved.refreshToken}),
        );
        await _vault.write(jsonEncode(session!.toJson()));
      } on AccountException catch (e) {
        if (e.code == 'network' || e.code == 'unavailable') {
          session = saved;
        } else {
          await _vault.clear();
          session = null;
        }
      }
      _changed();
    } catch (_) {
      session = null;
    }
  }

  Future<void> _localQueue = Future<void>.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _localQueue.then((_) => action());
    _localQueue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _setLocal(LocalIdentity user) async {
    final next = AccountSession(
      accessToken: '',
      refreshToken: '',
      userId: user.id,
      email: user.email,
      isLocal: true,
    );
    await _vault.write(jsonEncode(next.toJson()));
    session = next;
    _changed();
  }

  Future<void> signIn(String email, String password) async {
    await restore();
    if (isLocal) {
      return _serial(() async {
        await _setLocal(await _localAccounts.signIn(email, password));
      });
    }
    final next = AccountSession.fromJson(
      await request('/auth/login', {
        'email': email.trim(),
        'password': password,
      }),
    );
    await _vault.write(jsonEncode(next.toJson()));
    session = next;
    _changed();
  }

  Future<bool> create(String email, String password) async {
    await restore();
    if (isLocal) {
      return _serial(() async {
        await _setLocal(await _localAccounts.create(email, password));
        return true;
      });
    }
    final result = await request('/auth/signup', {
      'email': email.trim(),
      'password': password,
    });
    if (result['access_token'] is String) {
      final next = AccountSession.fromJson(result);
      await _vault.write(jsonEncode(next.toJson()));
      session = next;
      _changed();
      return true;
    }
    return false;
  }

  Future<void> recover(String email) async {
    if (isLocal) throw const AccountException('local_reset_unavailable');
    await request('/auth/recover', {'email': email.trim()});
  }

  Future<void> signOut() async {
    await restore();
    if (isLocal) {
      return _serial(() async {
        await _vault.clear();
        session = null;
        _changed();
      });
    }
    final token = session?.accessToken;
    try {
      if (token != null) await request('/auth/logout', {}, token: token);
    } catch (_) {
      /* Local logout works offline. */
    }
    await _vault.clear();
    session = null;
    _changed();
  }

  Future<void> deleteAccount() async {
    await restore();
    if (isLocal) {
      return _serial(() async {
        final id = session?.userId;
        if (id == null) throw const AccountException('sign_in');
        await _localAccounts.delete(id);
        await _vault.clear();
        session = null;
        _changed();
      });
    }
    final token = session?.accessToken;
    if (token == null) throw const AccountException('sign_in');
    await request(
      '/auth/account',
      {'confirmation': 'delete-my-account'},
      token: token,
      method: 'DELETE',
    );
    await _vault.clear();
    session = null;
    _changed();
  }

  Future<List<dynamic>> suggest({
    required String text,
    required int pageCount,
  }) async {
    if (isLocal) {
      if (!aiConfigured) throw const AccountException('unavailable');
      await restore();
      if (session == null) throw const AccountException('sign_in');
      return _workerAi.suggest(text: text, pageCount: pageCount);
    }
    await restore();
    var token = session?.accessToken;
    if (token == null) throw const AccountException('sign_in');
    final data = {'text': text, 'pageCount': pageCount};
    Map<String, dynamic> response;
    try {
      response = await request('/ai/topics', data, token: token);
    } on AccountException catch (e) {
      if (e.code != 'sign_in') rethrow;
      final refreshed = AccountSession.fromJson(
        await request('/auth/refresh', {
          'refresh_token': session!.refreshToken,
        }),
      );
      await _vault.write(jsonEncode(refreshed.toJson()));
      session = refreshed;
      _changed();
      token = refreshed.accessToken;
      response = await request('/ai/topics', data, token: token);
    }
    if (response['topics'] is! List) {
      throw const AccountException('invalid_response');
    }
    return response['topics'] as List;
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    if (_ownsLocalAccounts) {
      unawaited(_localAccounts.close().catchError((Object _) {}));
    }
    super.dispose();
  }
}

class AccountScope extends InheritedNotifier<AccountService> {
  const AccountScope({
    super.key,
    required AccountService service,
    required super.child,
  }) : super(notifier: service);
  static AccountService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
}

String accountMessage(String code) => switch (code) {
  'email_exists' => 'هذا البريد مسجّل بالفعل. سجّل الدخول به.',
  'invalid_email' => 'أدخل بريداً إلكترونياً صحيحاً.',
  'weak_password' => 'استخدم كلمة مرور من 8 إلى 256 حرفاً.',
  'local_reset_unavailable' => 'لا توجد استعادة بالبريد للحساب المحلي. كلمة المرور محفوظة كبصمة ولا يمكن عرضها.',
  'invalid_credentials' => 'البريد أو كلمة المرور غير صحيحة.',
  'email_not_confirmed' => 'تحقّق من رسالة تأكيد بريدك أولاً.',
  'email_confirmation' => 'أرسلنا رسالة تأكيد لبريدك. افتحها ثم سجّل الدخول.',
  'rate_limit' => 'وصلت إلى الحد المتاح حالياً. جرّب لاحقاً.',
  'sign_in' => 'سجّل الدخول أولاً لاستخدام هذه المساعدة.',
  'network' => 'تعذّر الاتصال. بيانات مذاكرتك محفوظة ويمكنك المتابعة دون حساب.',
  'invalid_response' => 'تعذّرت قراءة النتيجة. يمكنك المتابعة يدوياً.',
  _ => 'الخدمة غير متاحة الآن. يمكنك المتابعة دون حساب.',
};
