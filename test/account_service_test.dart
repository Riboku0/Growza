import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:growza/account_service.dart';

class MemoryVault implements SessionVault {
  String? value;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
    writes++;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

Map<String, Object> session([String token = 'access']) => {
  'access_token': token,
  'refresh_token': 'refresh',
  'user': {'id': 'student', 'email': 'student@example.test'},
};
void main() {
  test(
    'unconfigured account never sends credentials or invents success',
    () async {
      var calls = 0;
      final service = AccountService(
        local: false,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        vault: MemoryVault(),
      );
      addTearDown(service.dispose);
      expect(service.configured, false);
      await expectLater(
        service.signIn('e@example.test', 'password'),
        throwsA(isA<AccountException>()),
      );
      expect(calls, 0);
      expect(service.session, isNull);
    },
  );
  test('rejects unsafe endpoint and accepts HTTPS', () {
    for (final url in [
      'https://name:pass@example.test',
      'https://example.test?q=secret',
      'file:///tmp/a',
      'http://example.test',
    ]) {
      final service = AccountService(local: false, workerUrl: url);
      expect(service.configured, false);
      service.dispose();
    }
    final service = AccountService(
      local: false,
      workerUrl: 'https://worker.example.test',
    );
    expect(service.configured, true);
    service.dispose();
  });
  test(
    'successful login stores tokens only in vault, trims email and posts JSON',
    () async {
      final vault = MemoryVault();
      final service = AccountService(
        local: false,
        workerUrl: 'https://worker.example.test',
        vault: vault,
        client: MockClient((request) async {
          expect(request.url.path, '/auth/login');
          expect(jsonDecode(request.body), {
            'email': 'student@example.test',
            'password': 'secret-password',
          });
          return http.Response(jsonEncode(session()), 200);
        }),
      );
      addTearDown(service.dispose);
      await service.signIn(' student@example.test ', 'secret-password');
      expect(service.session!.userId, 'student');
      expect(vault.value, contains('access'));
      expect(vault.value, isNot(contains('secret-password')));
    },
  );
  test('email confirmation leaves app signed out', () async {
    final vault = MemoryVault();
    final service = AccountService(
      local: false,
      workerUrl: 'https://worker.example.test',
      vault: vault,
      client: MockClient(
        (_) async => http.Response('{"confirmation_required":true}', 200),
      ),
    );
    addTearDown(service.dispose);
    expect(await service.create('e@example.test', 'password'), false);
    expect(service.session, isNull);
    expect(vault.value, isNull);
  });
  test(
    'failed login never writes vault and preserves human error code',
    () async {
      final vault = MemoryVault();
      final service = AccountService(
        local: false,
        workerUrl: 'https://worker.example.test',
        vault: vault,
        client: MockClient(
          (_) async => http.Response('{"code":"invalid_credentials"}', 400),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.signIn('e@example.test', 'password'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
      expect(vault.writes, 0);
    },
  );
  test(
    'offline restore keeps local token and offline logout clears it',
    () async {
      final vault = MemoryVault()..value = jsonEncode(session());
      final service = AccountService(
        local: false,
        workerUrl: 'https://worker.example.test',
        vault: vault,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(service.dispose);
      await service.restore();
      expect(service.session!.userId, 'student');
      await service.signOut();
      expect(service.session, isNull);
      expect(vault.value, isNull);
    },
  );
  test('AI retries once with refreshed token after expiry', () async {
    final vault = MemoryVault();
    var aiCalls = 0;
    final service = AccountService(
      local: false,
      workerUrl: 'https://worker.example.test',
      vault: vault,
      client: MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(jsonEncode(session()), 200);
        }
        if (request.url.path == '/auth/refresh') {
          return http.Response(jsonEncode(session('new-access')), 200);
        }
        aiCalls++;
        if (aiCalls == 1) return http.Response('{"code":"sign_in"}', 401);
        expect(request.headers['Authorization'], 'Bearer new-access');
        return http.Response(
          '{"topics":[{"title":"Topic","startPage":1,"endPage":2}]}',
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    await service.signIn('e@example.test', 'password');
    expect(await service.suggest(text: 'headings', pageCount: 2), hasLength(1));
    expect(aiCalls, 2);
  });
  test('invalid or oversized responses are rejected', () async {
    for (final body in ['not json', 'a' * 300000]) {
      final service = AccountService(
        local: false,
        workerUrl: 'https://worker.example.test',
        vault: MemoryVault(),
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.request('/test', {}),
        throwsA(
          isA<AccountException>().having(
            (e) => e.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    }
  });
}
