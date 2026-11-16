import 'package:growza/account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/main.dart';
import 'package:growza/auth_screen.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';

class WelcomeStore extends StudyStorage {
  late String data;
  @override
  Future<StudyWorkspace> load() async => decode(data);
  @override
  Future<void> save(String raw) async {
    data = raw;
  }
}

// UI tests isolate transport. account_service_test exercises real HTTP parsing
// with MockClient; widget fake clocks should not drive HTTP byte streams.
class WelcomeAccounts extends AccountService {
  WelcomeAccounts({this.restored = false})
    : super(workerUrl: 'https://worker.example.test');
  final bool restored;
  static const identity = AccountSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    userId: 'student',
    email: 'student@example.test',
  );
  @override
  Future<void> restore() async {
    if (restored) {
      session = identity;
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    if (email != 'student@example.test' || password != 'temporary-password') {
      throw const AccountException('invalid_credentials');
    }
    session = identity;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'Configured sign-in enters Home without writing a password into study data',
    (t) async {
      final service = WelcomeAccounts();
      addTearDown(service.dispose);
      final store = WelcomeStore();
      store.data = store.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('Math', DateTime(2026, 12, 1), [
              const StudyPart(1, 'Algebra', 25),
            ]),
          ],
        ),
      );
      await t.pumpWidget(GrowzaApp(storage: store, accounts: service));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('welcome-sign-in')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('auth-email')),
        'student@example.test',
      );
      await t.enterText(
        find.byKey(const ValueKey('auth-password')),
        'temporary-password',
      );
      await t.ensureVisible(find.byKey(const ValueKey('auth-submit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('auth-submit')));
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.byKey(const ValueKey('welcome-sign-in')), findsNothing);
      expect(service.session?.userId, 'student');
      expect(store.data, isNot(contains('temporary-password')));
      expect(store.decode(store.data).subjects.single.name, 'Math');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('A restored account returns directly to local study', (t) async {
    final service = WelcomeAccounts(restored: true);
    addTearDown(service.dispose);
    await t.pumpWidget(GrowzaApp(accounts: service));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('welcome-sign-in')), findsNothing);
    expect(find.text('أضف مادتك الأولى'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Cold launch offers sign in, creation and guest before Home without losing saved data',
    (t) async {
      final store = WelcomeStore();
      store.data = store.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('Math', DateTime(2026, 12, 1), [
              const StudyPart(1, 'Algebra', 25),
            ]),
          ],
        ),
      );
      await t.pumpWidget(GrowzaApp(storage: store));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-sign-in')), findsOneWidget);
      expect(find.text('مستعد للمذاكرة؟'), findsNothing);
      await t.tap(find.byKey(const ValueKey('welcome-sign-in')));
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('متابعة دون حساب'),
        120,
        scrollable: find
            .descendant(
              of: find.byType(AuthScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.ensureVisible(find.text('متابعة دون حساب'));
      await t.pumpAndSettle();
      await t.tap(find.text('متابعة دون حساب'));
      await t.pumpAndSettle();
      expect(find.text('مستعد للمذاكرة؟'), findsOneWidget);
      expect(store.decode(store.data).subjects.single.name, 'Math');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Create account starts on the correct form; backing out keeps entry choices',
    (t) async {
      await t.pumpWidget(const GrowzaApp());
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('welcome-create')));
      await t.pumpAndSettle();
      expect(find.text('تأكيد كلمة المرور'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-guest')), findsOneWidget);
    },
  );
}
