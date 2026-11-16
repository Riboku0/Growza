import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growza/account_service.dart';
import 'package:growza/local_account_store.dart';
import 'package:growza/password_hash.dart';

import 'account_service_test.dart' show MemoryVault;

LocalAccountStore store([String path = inMemoryDatabasePath]) =>
    LocalAccountStore(
      factory: databaseFactoryFfi,
      path: path,
      hasher: const PasswordHasher(iterations: 1000),
    );
Matcher code(String code) =>
    isA<AccountException>().having((e) => e.code, 'code', code);
void main() {
  setUpAll(sqfliteFfiInit);
  test('Local credentials survive reopen; email normalizes and wrong passwords fail', () async {
    final folder = await Directory.systemTemp.createTemp('growza-local-auth');
    addTearDown(() => folder.delete(recursive: true));
    final path = '${folder.path}/accounts.db';
    var users = store(path);
    final created = await users.create(
      ' Student@Example.test ',
      'study-password',
    );
    await users.close();
    users = store(path);
    addTearDown(users.close);
    expect(
      await users.signIn('STUDENT@example.test', 'study-password'),
      created,
    );
    await expectLater(
      users.signIn('student@example.test', 'incorrect-password'),
      throwsA(code('invalid_credentials')),
    );
    expect(await users.find(created.id), created);
    final row = (await (await users.database).query('local_accounts')).single;
    expect(row['email'], 'student@example.test');
    expect(row.containsKey('password'), false);
    expect(jsonEncode(row), isNot(contains('study-password')));
    expect(base64Decode(row['salt'] as String), hasLength(16));
    expect(base64Decode(row['digest'] as String), hasLength(32));
  });
  test(
    'Production password fingerprint is salted and uses 600000 PBKDF2 rounds',
    () async {
      expect(LocalAuthRules.iterations, 600000);
      const hasher = PasswordHasher();
      final first = await hasher.create('كلمة سر طويلة 🌿');
      expect(first.iterations, 600000);
      expect(await hasher.verify('كلمة سر طويلة 🌿', first), true);
      final second = await const PasswordHasher(iterations: 1000)
          .create('كلمة سر طويلة 🌿');
      expect(first.salt, isNot(second.salt));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'Malformed email is rejected by storage before creating credentials',
    () async {
      final users = store();
      addTearDown(users.close);
      for (final email in [
        'adsad@gk.co,',
        'a@do_main.com',
        'a..b@example.com',
      ]) {
        await expectLater(
          users.create(email, 'password123'),
          throwsA(code('invalid_email')),
        );
      }
      expect(await (await users.database).query('local_accounts'), isEmpty);
    },
  );
  test(
    'Two simultaneous registrations cannot duplicate a normalized email',
    () async {
      final users = store();
      addTearDown(users.close);
      final outcomes = await Future.wait([
        users
            .create('same@example.test', 'password-123')
            .then<Object>((u) => u, onError: (Object e) => e),
        users
            .create(' SAME@example.test ', 'password-123')
            .then<Object>((u) => u, onError: (Object e) => e),
      ]);
      expect(
        outcomes.whereType<AccountException>().single.code,
        'email_exists',
      );
      expect(
        await (await users.database).query('local_accounts'),
        hasLength(1),
      );
    },
  );
  test(
    'Validation rejects invalid emails and short or excessive passwords',
    () async {
      final users = store();
      addTearDown(users.close);
      await expectLater(
        users.create('invalid', 'password123'),
        throwsA(code('invalid_email')),
      );
      for (final password in ['short', 'x' * 257]) {
        await expectLater(
          users.create('e@example.test', password),
          throwsA(code('weak_password')),
        );
      }
      expect(await (await users.database).query('local_accounts'), isEmpty);
    },
  );
  test(
    'Email is matched as data and password spaces are not silently trimmed',
    () async {
      final users = store();
      addTearDown(users.close);
      await users.create('normal@example.test', ' password123 ');
      await expectLater(
        users.signIn("' OR 1=1 --@example.test", ' password123 '),
        throwsA(isA<AccountException>()),
      );
      await expectLater(
        users.signIn('normal@example.test', 'password123'),
        throwsA(code('invalid_credentials')),
      );
      expect(
        (await users.signIn('normal@example.test', ' password123 ')).email,
        'normal@example.test',
      );
    },
  );
  test(
    'Default account works offline without any HTTP or verification',
    () async {
      final users = store();
      addTearDown(users.close);
      final vault = MemoryVault();
      var requests = 0;
      final accounts = AccountService(
        localAccounts: users,
        vault: vault,
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
      addTearDown(accounts.dispose);
      expect(accounts.isLocal, true);
      expect(accounts.configured, true);
      expect(accounts.cloudConfigured, false);
      expect(
        await accounts.create('student@example.test', 'password123'),
        true,
      );
      expect(accounts.session!.isLocal, true);
      expect(accounts.session!.accessToken, isEmpty);
      expect(vault.value, isNot(contains('password123')));
      final id = accounts.session!.userId;
      await accounts.signOut();
      expect(vault.value, isNull);
      expect(accounts.session, isNull);
      expect(await users.find(id), isNotNull);
      await accounts.signIn('student@example.test', 'password123');
      expect(accounts.session!.userId, id);
      await expectLater(
        accounts.recover('student@example.test'),
        throwsA(code('local_reset_unavailable')),
      );
      await expectLater(
        accounts.suggest(text: 'headings', pageCount: 3),
        throwsA(code('unavailable')),
      );
      expect(requests, 0);
    },
  );
  test(
    'Remembered session restores only while its local account still exists',
    () async {
      final users = store();
      addTearDown(users.close);
      final vault = MemoryVault();
      final first = AccountService(localAccounts: users, vault: vault);
      await first.create('student@example.test', 'password123');
      final id = first.session!.userId;
      first.dispose();
      final restored = AccountService(localAccounts: users, vault: vault);
      await restored.restore();
      expect(restored.session!.userId, id);
      restored.dispose();
      await users.delete(id);
      final missing = AccountService(localAccounts: users, vault: vault);
      addTearDown(missing.dispose);
      await missing.restore();
      expect(missing.session, isNull);
      expect(vault.value, isNull);
    },
  );
  test('Failed local sign in never creates a remembered session', () async {
    final users = store();
    addTearDown(users.close);
    await users.create('student@example.test', 'password123');
    final vault = MemoryVault();
    final accounts = AccountService(localAccounts: users, vault: vault);
    addTearDown(accounts.dispose);
    await expectLater(
      accounts.signIn('student@example.test', 'wrong-password'),
      throwsA(code('invalid_credentials')),
    );
    expect(accounts.session, isNull);
    expect(vault.value, isNull);
  });
  test(
    'Logout queued after a login wins, retaining credentials for next login',
    () async {
      final users = store();
      addTearDown(users.close);
      await users.create('student@example.test', 'password123');
      final vault = MemoryVault();
      final accounts = AccountService(localAccounts: users, vault: vault);
      addTearDown(accounts.dispose);
      await Future.wait([
        accounts.signIn('student@example.test', 'password123'),
        accounts.signOut(),
      ]);
      expect(accounts.session, isNull);
      expect(vault.value, isNull);
      expect(
        (await users.signIn('student@example.test', 'password123')).email,
        'student@example.test',
      );
    },
  );
  test(
    'Delete account removes only the selected credential identity',
    () async {
      final users = store();
      addTearDown(users.close);
      final other = await users.create('other@example.test', 'password123');
      final accounts = AccountService(
        localAccounts: users,
        vault: MemoryVault(),
      );
      addTearDown(accounts.dispose);
      await accounts.create('student@example.test', 'password123');
      final id = accounts.session!.userId;
      await accounts.deleteAccount();
      expect(accounts.session, isNull);
      expect(await users.find(id), isNull);
      expect(await users.find(other.id), other);
    },
  );
}
