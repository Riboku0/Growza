import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:growza/account_service.dart';
import 'package:growza/worker_ai_service.dart';

import 'account_service_test.dart' show MemoryVault;

const endpoint = 'https://worker.example.test';
final tokenA = 'a' * 43;
final tokenB = 'b' * 43;
http.Response enrolled(String token) =>
    http.Response(jsonEncode({'token': token}), 201);
http.Response topics() => http.Response(
  jsonEncode({
    'topics': [
      {'title': 'Topic', 'startPage': 1, 'endPage': 2},
    ],
  }),
  200,
);
Matcher failure(String code) =>
    isA<AccountException>().having((e) => e.code, 'code', code);
WorkerAiService service(
  http.Client client,
  MemoryVault vault, [
  String url = endpoint,
]) => WorkerAiService(client: client, base: Uri.parse(url), vault: vault);

void main() {
  test('local account service connects only on explicit AI request without credentials', () async {
    final requests = <http.Request>[];
    final vault = MemoryVault(), installation = MemoryVault();
    final accounts = AccountService(
      workerUrl: endpoint,
      vault: vault,
      installationVault: installation,
      client: MockClient((request) async {
        requests.add(request);
        return request.url.path == '/installations'
            ? enrolled(tokenA)
            : topics();
      }),
    );
    addTearDown(accounts.dispose);
    expect(accounts.aiConfigured, true);
    expect(accounts.cloudConfigured, false);
    await accounts.restore();
    expect(requests, isEmpty);
    await expectLater(
      accounts.suggest(text: 'Headings', pageCount: 2),
      throwsA(failure('sign_in')),
    );
    expect(requests, isEmpty);
    accounts.session = const AccountSession(
      accessToken: '',
      refreshToken: '',
      userId: 'private-local-id',
      email: 'private@example.test',
      isLocal: true,
    );
    expect(
      await accounts.suggest(text: 'Headings', pageCount: 2),
      hasLength(1),
    );
    expect(requests.map((r) => r.url.path), ['/installations', '/ai/topics']);
    expect(jsonDecode(requests[0].body), isEmpty);
    expect(requests[0].headers.containsKey('Authorization'), false);
    expect(jsonDecode(requests[1].body), {'text': 'Headings', 'pageCount': 2});
    expect(requests[1].headers['Authorization'], 'Bearer $tokenA');
    for (final request in requests) {
      expect(request.followRedirects, false);
      expect(request.body, isNot(contains('private')));
    }
    expect(installation.value, contains(tokenA));
    expect(vault.value, isNull);
  });
  test(
    'remembered credential is reused after reopening and scoped to endpoint',
    () async {
      final vault = MemoryVault();
      var enrollments = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/installations') {
          enrollments++;
          return enrolled(tokenA);
        }
        return topics();
      });
      addTearDown(client.close);
      await service(client, vault).suggest(text: 'h', pageCount: 2);
      await service(client, vault).suggest(text: 'h', pageCount: 2);
      expect(enrollments, 1);
      await service(
        client,
        vault,
        'https://different.example.test',
      ).suggest(text: 'h', pageCount: 2);
      expect(enrollments, 2);
      expect(vault.value, contains('different.example.test'));
    },
  );
  test('concurrent requests share one enrollment', () async {
    var enrollments = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/installations') {
        enrollments++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return enrolled(tokenA);
      }
      return topics();
    });
    addTearDown(client.close);
    final worker = service(client, MemoryVault());
    await Future.wait(
      List.generate(3, (_) => worker.suggest(text: 'h', pageCount: 2)),
    );
    expect(enrollments, 1);
  });
  test(
    'expired installation enrolls once and retries with new token',
    () async {
      final vault = MemoryVault()
        ..value = jsonEncode({'endpoint': endpoint, 'token': tokenA});
      var calls = 0, enrollments = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/installations') {
          enrollments++;
          return enrolled(tokenB);
        }
        calls++;
        return request.headers['Authorization'] == 'Bearer $tokenA'
            ? http.Response('{"code":"sign_in"}', 401)
            : topics();
      });
      addTearDown(client.close);
      expect(
        await service(client, vault).suggest(text: 'h', pageCount: 2),
        hasLength(1),
      );
      expect(enrollments, 1);
      expect(calls, 2);
      expect(vault.value, contains(tokenB));
    },
  );
  test(
    'second authentication failure stops instead of infinite enrollment',
    () async {
      var enrollments = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/installations') {
          enrollments++;
          return enrolled(enrollments == 1 ? tokenA : tokenB);
        }
        return http.Response('{"code":"sign_in"}', 401);
      });
      addTearDown(client.close);
      await expectLater(
        service(client, MemoryVault()).suggest(text: 'h', pageCount: 2),
        throwsA(failure('sign_in')),
      );
      expect(enrollments, 2);
    },
  );
  test('rate limit and server failure never trigger re-enrollment or hidden retries', () async {
    for (final status in [429, 503]) {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({'code': status == 429 ? 'rate_limit' : 'unavailable'}),
          status,
        );
      });
      final vault = MemoryVault()
        ..value = jsonEncode({'endpoint': endpoint, 'token': tokenA});
      await expectLater(
        service(client, vault).suggest(text: 'h', pageCount: 2),
        throwsA(failure(status == 429 ? 'rate_limit' : 'unavailable')),
      );
      expect(calls, 1);
      client.close();
    }
  });
  test('malformed enrollment is never saved or used', () async {
    for (final body in ['not json', '{"token":"short"}', '[]']) {
      final client = MockClient((_) async => http.Response(body, 201));
      final vault = MemoryVault();
      await expectLater(
        service(client, vault).suggest(text: 'h', pageCount: 2),
        throwsA(failure('invalid_response')),
      );
      expect(vault.value, isNull);
      client.close();
    }
  });
  test('corrupt cached token is replaced safely', () async {
    final vault = MemoryVault()..value = '{invalid';
    final client = MockClient(
      (request) async =>
          request.url.path == '/installations' ? enrolled(tokenA) : topics(),
    );
    addTearDown(client.close);
    expect(
      await service(client, vault).suggest(text: 'h', pageCount: 2),
      hasLength(1),
    );
    expect(vault.value, contains(tokenA));
  });
  test('oversized/malformed AI result and network failures become controlled errors', () async {
    for (final body in ['{"topics":{}}', '[1]', 'x' * (256 * 1024 + 1)]) {
      final client = MockClient((_) async => http.Response(body, 200));
      final vault = MemoryVault()
        ..value = jsonEncode({'endpoint': endpoint, 'token': tokenA});
      await expectLater(
        service(client, vault).suggest(text: 'h', pageCount: 2),
        throwsA(failure('invalid_response')),
      );
      client.close();
    }
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      service(client, MemoryVault()).suggest(text: 'h', pageCount: 2),
      throwsA(failure('network')),
    );
  });
  test('invalid input is rejected before any network request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return topics();
    });
    addTearDown(client.close);
    final worker = service(client, MemoryVault());
    for (final text in ['', 'x' * 12001]) {
      await expectLater(
        worker.suggest(text: text, pageCount: 2),
        throwsA(failure('invalid_request')),
      );
    }
    await expectLater(
      worker.suggest(text: 'h', pageCount: 2001),
      throwsA(failure('invalid_request')),
    );
    expect(calls, 0);
  });
}
