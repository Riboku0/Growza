import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:growza/account_service.dart';
import 'package:growza/local_account_store.dart';

void main() {
  if (!const bool.fromEnvironment('GROWZA_VERIFICATION')) {
    throw StateError('Use only the isolated verification package');
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Local account persists, verifies passwords and remembers login without network',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Growza Verification — local account')),
          ),
        ),
      );
      final path =
          '${await getDatabasesPath()}/growza-local-account-verification.db';
      await deleteDatabase(path);
      const vault = SecureSessionVault(
        key: 'growza.verification.local-account',
      );
      await vault.clear();
      var users = LocalAccountStore(path: path);
      var accounts = AccountService(localAccounts: users, vault: vault);
      final watch = Stopwatch()..start();
      try {
        expect(accounts.isLocal, true);
        expect(accounts.cloudConfigured, false);
        expect(
          await accounts.create(' Student@Example.test ', 'مذاكرة 🌿 12345'),
          true,
        );
        final id = accounts.session!.userId;
        expect(accounts.session!.email, 'student@example.test');
        expect(accounts.session!.isLocal, true);
        final rows = await (await users.database).query('local_accounts');
        expect(rows, hasLength(1));
        expect(rows.single['iterations'], 600000);
        expect(jsonEncode(rows), isNot(contains('مذاكرة 🌿 12345')));
        accounts.dispose();
        await users.close();
        users = LocalAccountStore(path: path);
        accounts = AccountService(localAccounts: users, vault: vault);
        await accounts.restore();
        expect(accounts.session!.userId, id);
        await accounts.signOut();
        expect(accounts.session, isNull);
        expect(await vault.read(), isNull);
        await expectLater(
          accounts.signIn('student@example.test', 'wrong-password'),
          throwsA(
            isA<AccountException>().having(
              (e) => e.code,
              'code',
              'invalid_credentials',
            ),
          ),
        );
        await accounts.signIn('STUDENT@example.test', 'مذاكرة 🌿 12345');
        expect(accounts.session!.userId, id);
        await expectLater(
          accounts.create('student@example.test', 'different-password'),
          throwsA(
            isA<AccountException>().having(
              (e) => e.code,
              'code',
              'email_exists',
            ),
          ),
        );
        await accounts.deleteAccount();
        expect(accounts.session, isNull);
        expect(await users.find(id), isNull);
        watch.stop();
        binding.reportData = {
          'passed': true,
          'localOnly': true,
          'iterations': 600000,
          'elapsedMs': watch.elapsedMilliseconds,
        };
        await File(
          '${await getDatabasesPath()}/growza-local-account-verification-results.json',
        ).writeAsString(
          jsonEncode({
            'passed': true,
            'elapsedMs': watch.elapsedMilliseconds,
            'iterations': 600000,
            'localOnly': true,
          }),
        );
      } finally {
        accounts.dispose();
        await users.close();
        await vault.clear();
        await deleteDatabase(path);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
