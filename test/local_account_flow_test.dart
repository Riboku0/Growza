import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/main.dart';
import 'package:growza/account_service.dart';
import 'package:growza/local_account_store.dart';
import 'package:growza/study_data.dart';
import 'package:growza/auth_screen.dart';
import 'package:growza/study_storage.dart';

import 'account_service_test.dart' show MemoryVault;
import 'frontend_completion_test.dart' as previews;

class FlowAccounts implements LocalAccounts {
  LocalIdentity? user;
  String? _password;
  @override
  Future<LocalIdentity> create(String email, String password) async {
    if (user != null) throw const AccountException('email_exists');
    user = (id: 'local-flow', email: email.trim().toLowerCase());
    _password = password;
    return user!;
  }

  @override
  Future<LocalIdentity> signIn(String email, String password) async {
    if (user?.email != email.trim().toLowerCase() || password != _password) {
      throw const AccountException('invalid_credentials');
    }
    return user!;
  }

  @override
  Future<LocalIdentity?> find(String id) async => user?.id == id ? user : null;
  @override
  Future<void> delete(String id) async {
    if (user?.id == id) {
      user = null;
      _password = null;
    }
  }

  @override
  Future<void> close() async {}
}

class FlowStudyStorage extends StudyStorage {
  late String saved = encode(
    StudyWorkspace(
      subjects: [
        StudySubject('مادة محفوظة', DateTime(2026, 12, 1), [
          const StudyPart(1, 'موضوع', 25),
        ], id: 'existing-subject'),
      ],
    ),
  );
  @override
  Future<StudyWorkspace> load() async => decode(saved);
  @override
  Future<void> save(String raw) async {
    saved = raw;
  }
}

Future<void> tap(WidgetTester t, Finder target) async {
  if (target.hitTestable().evaluate().isEmpty) {
    final list = find.byType(ListView).hitTestable().last;
    await t.scrollUntilVisible(
      target,
      160,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
  }
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> fill(
  WidgetTester t,
  String password, {
  bool create = false,
}) async {
  await t.enterText(
    find.byKey(const ValueKey('auth-email')),
    'student@example.test',
  );
  await t.enterText(find.byKey(const ValueKey('auth-password')), password);
  if (create) {
    await t.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      password,
    );
  }
  await tap(t, find.byKey(const ValueKey('auth-submit')));
}

void main() {
  testWidgets(
    'Local create, logout, wrong password, login and relaunch preserve study data',
    (t) async {
      t.view.physicalSize = const Size(392, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final users = FlowAccounts(),
          vault = MemoryVault(),
          storage = FlowStudyStorage();
      final account = AccountService(localAccounts: users, vault: vault);
      addTearDown(account.dispose);
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture-root'),
          child: GrowzaApp(accounts: account, storage: storage),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('welcome-create')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-reset')), findsNothing);
      await fill(t, 'local-password', create: true);
      expect(find.byType(AuthScreen), findsNothing);
      expect(account.session?.email, 'student@example.test');
      expect(
        storage.decode(storage.saved).subjects.single.id,
        'existing-subject',
      );
      expect(storage.saved, isNot(contains('local-password')));
      expect(vault.value, isNot(contains('local-password')));
      await t.tap(find.byKey(const ValueKey('header-settings')));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('settings-sign-out')));
      expect(find.byKey(const ValueKey('welcome-sign-in')), findsOneWidget);
      expect(account.session, isNull);
      await t.tap(find.byKey(const ValueKey('welcome-sign-in')));
      await t.pumpAndSettle();
      await fill(t, 'incorrect-password');
      expect(find.text('البريد أو كلمة المرور غير صحيحة.'), findsOneWidget);
      await fill(t, 'local-password');
      expect(find.byType(AuthScreen), findsNothing);
      expect(account.session, isNotNull);
      await t.pumpWidget(const SizedBox.shrink());
      final reloaded = AccountService(localAccounts: users, vault: vault);
      addTearDown(reloaded.dispose);
      await t.pumpWidget(GrowzaApp(accounts: reloaded, storage: storage));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-sign-in')), findsNothing);
      expect(reloaded.session?.email, 'student@example.test');
      expect(
        storage.decode(storage.saved).subjects.single.id,
        'existing-subject',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Account form hides implementation labels and rejects a trailing comma before signup',
    (t) async {
      t.view.physicalSize = const Size(392, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final users = FlowAccounts(), storage = FlowStudyStorage();
      final account = AccountService(
        localAccounts: users,
        vault: MemoryVault(),
      );
      addTearDown(account.dispose);
      await t.pumpWidget(GrowzaApp(accounts: account, storage: storage));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('welcome-create')));
      await t.pumpAndSettle();
      expect(
        find.text('حساب محلي على هذا الجهاز، دون إرسال بريد أو رمز تحقق.'),
        findsNothing,
      );
      expect(
        find.text(
          'تذكّر كلمة مرورك؛ لا توجد استعادة بالبريد في الحساب المحلي.',
        ),
        findsNothing,
      );
      await t.enterText(
        find.byKey(const ValueKey('auth-email')),
        'adsad@gk.co,',
      );
      await t.enterText(
        find.byKey(const ValueKey('auth-password')),
        'password123',
      );
      await t.enterText(
        find.byKey(const ValueKey('auth-confirmation')),
        'password123',
      );
      await tap(t, find.byKey(const ValueKey('auth-submit')));
      expect(find.text('أدخل بريداً إلكترونياً صحيحاً.'), findsOneWidget);
      expect(users.user, isNull);
      await t.enterText(
        find.byKey(const ValueKey('auth-email')),
        'adsad@gk.co',
      );
      await tap(t, find.byKey(const ValueKey('auth-submit')));
      expect(account.session?.email, 'adsad@gk.co');
      expect(find.byType(AuthScreen), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Local privacy deletion returns to entry and leaves subjects intact',
    (t) async {
      final users = FlowAccounts(),
          vault = MemoryVault(),
          storage = FlowStudyStorage();
      final account = AccountService(localAccounts: users, vault: vault);
      addTearDown(account.dispose);
      await account.create('student@example.test', 'local-password');
      await t.pumpWidget(GrowzaApp(accounts: account, storage: storage));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('header-settings')));
      await t.pumpAndSettle();
      await tap(t, find.text('الخصوصية والحساب'));
      await tap(t, find.text('حذف حسابي'));
      await t.tap(find.text('حذف الحساب'));
      await t.pumpAndSettle();
      expect(account.session, isNull);
      expect(users.user, isNull);
      expect(find.byKey(const ValueKey('welcome-sign-in')), findsOneWidget);
      expect(
        storage.decode(storage.saved).subjects.single.id,
        'existing-subject',
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final language in ['ar', 'en']) {
    testWidgets('Local authentication fits narrow enlarged $language layout', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 760);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final users = FlowAccounts(),
          vault = MemoryVault(),
          storage = FlowStudyStorage();
      final w = storage.decode(storage.saved)..languageCode = language;
      storage.saved = storage.encode(w);
      final account = AccountService(localAccounts: users, vault: vault);
      addTearDown(account.dispose);
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture-root'),
          child: GrowzaApp(accounts: account, storage: storage),
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('welcome-create')));
      expect(find.byKey(const ValueKey('auth-reset')), findsNothing);
      expect(t.takeException(), isNull);
      await previews.capture(t, 'Local-Account-$language');
    });
  }
}
