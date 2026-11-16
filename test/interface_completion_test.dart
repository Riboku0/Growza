import 'package:growza/account_service.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/main.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_recommendation.dart';
import 'package:growza/focus_screen.dart';
import 'package:growza/auth_screen.dart';
import 'package:growza/app_strings.dart';

import 'frontend_completion_test.dart' as previews;

class InvalidLocalLogin extends AccountService {
  @override
  Future<void> restore() async {}
  @override
  Future<void> signIn(String email, String password) async {
    throw const AccountException('invalid_credentials');
  }
}

class MemoryStore extends StudyStorage {
  late String data;
  @override
  Future<StudyWorkspace> load() async => decode(data);
  @override
  Future<void> save(String snapshot) async {
    data = snapshot;
  }
}

final day = DateTime(2026, 11, 14, 12);
MemoryStore fixture({String? language = 'ar', bool? dark}) {
  final store = MemoryStore();
  store.data = store.encode(
    StudyWorkspace(
      languageCode: language,
      darkMode: dark,
      subjects: [
        StudySubject('Biology', day.add(const Duration(days: 2)), [
          const StudyPart(1, 'Cells', 25),
          const StudyPart(2, 'DNA', 25, completed: true),
        ]),
        StudySubject('Physics', day.add(const Duration(days: 5)), [
          const StudyPart(1, 'Waves', 25),
        ]),
      ],
      recentSubjects: ['Physics'],
    ),
  );
  return store;
}

Future<void> open(
  WidgetTester t,
  MemoryStore s, {
  DateTime Function()? now,
  AccountService? accounts,
}) async {
  await t.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture-root'),
      child: GrowzaApp(
        showWelcome: false,
        storage: s,
        accounts: accounts,
        timerNow: now ?? () => day,
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> settings(WidgetTester t) async {
  final scroll = find.byWidgetPredicate(
    (w) =>
        w is Scrollable &&
        (w.axisDirection == AxisDirection.down ||
            w.axisDirection == AxisDirection.up),
  );
  if (scroll.evaluate().isNotEmpty) {
    t.state<ScrollableState>(scroll.first).position.jumpTo(0);
    await t.pumpAndSettle();
  }
  await t.tap(find.byKey(const ValueKey('header-settings')));
  await t.pumpAndSettle();
}

Future<void> closeSettings(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.close_rounded).last);
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder target) async {
  if (target.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                (w.axisDirection == AxisDirection.down ||
                    w.axisDirection == AxisDirection.up),
          )
          .last,
    );
  }
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  test('Suggestion uses nearest unfinished exam, remaining-count tie and stable fallback', () {
    final s = fixture().decode(fixture().data);
    final subjects = s.subjects;
    expect(recommendSubject(subjects, ['Physics'], day), same(subjects.first));
    final a = StudySubject('A', day.add(const Duration(days: 1)), [
      const StudyPart(1, 'a', 25),
    ]);
    final b = StudySubject('B', a.exam, [
      const StudyPart(1, 'b', 25),
      const StudyPart(2, 'c', 25),
    ]);
    expect(recommendSubject([a, b], [], day), same(b));
    expect(
      recommendSubject([a.withParts([]), b.withParts([])], ['A'], day)?.name,
      'A',
    );
    expect(recommendSubject([], [], day), isNull);
  });
  test('Legacy language stays Arabic; explicit phone language and choices round-trip', () {
    final s = fixture();
    final data = jsonDecode(s.data) as Map<String, dynamic>;
    data.remove('languageCode');
    final legacy = s.decode(jsonEncode(data));
    expect(legacy.languageCode, 'ar');
    final subjects = jsonEncode(data['subjects']);
    for (final language in <String?>['en', 'ar', null]) {
      legacy.languageCode = language;
      final restored = s.decode(s.encode(legacy));
      expect(restored.languageCode, language);
      expect(
        jsonEncode(restored.subjects.map((x) => x.toJson()).toList()),
        subjects,
      );
    }
  });
  testWidgets(
    'Settings change both languages and all appearance modes, persist after restart',
    (t) async {
      await t.binding.setSurfaceSize(const Size(392, 850));
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(392, 850);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      addTearDown(() => t.binding.setSurfaceSize(null));
      final s = fixture();
      await open(t, s);
      await settings(t);
      await previews.capture(t, 'Interface-Settings-Arabic');
      await tap(t, find.byKey(const ValueKey('language-en')));
      expect(find.text('Appearance'), findsOneWidget);
      expect(
        Directionality.of(t.element(find.text('Appearance'))),
        TextDirection.ltr,
      );
      await tap(t, find.byKey(const ValueKey('appearance-dark')));
      expect(
        Theme.of(t.element(find.text('Appearance'))).brightness,
        Brightness.dark,
      );
      await previews.capture(t, 'Interface-Settings-English-Night');
      await tap(t, find.byKey(const ValueKey('appearance-system')));
      expect(s.decode(s.data).darkMode, isNull);
      await tap(t, find.byKey(const ValueKey('appearance-light')));
      expect(s.decode(s.data).darkMode, false);
      await closeSettings(t);
      expect(find.text('Ready to study?'), findsOneWidget);
      await previews.capture(t, 'Interface-Home-English');
      await t.pumpWidget(const SizedBox.shrink());
      await open(t, s);
      expect(find.text('Ready to study?'), findsOneWidget);
      expect(s.decode(s.data).languageCode, 'en');
      await settings(t);
      await tap(t, find.byKey(const ValueKey('language-ar')));
      expect(
        Directionality.of(t.element(find.text('المظهر'))),
        TextDirection.rtl,
      );
      await closeSettings(t);
      expect(find.text('مستعد للمذاكرة؟'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Phone language follows system locale and explicit selection overrides it',
    (t) async {
      t.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
      addTearDown(t.platformDispatcher.clearLocalesTestValue);
      final s = fixture(language: null);
      await open(t, s);
      expect(find.text('Ready to study?'), findsOneWidget);
      t.platformDispatcher.localesTestValue = [const Locale('ar', 'SA')];
      await t.pumpAndSettle();
      expect(find.text('مستعد للمذاكرة؟'), findsOneWidget);
      await settings(t);
      await tap(t, find.byKey(const ValueKey('language-en')));
      await closeSettings(t);
      t.platformDispatcher.localesTestValue = [const Locale('ar', 'SA')];
      await t.pumpAndSettle();
      expect(find.text('Ready to study?'), findsOneWidget);
    },
  );
  testWidgets(
    'Language and theme switches preserve an active timer and its identity',
    (t) async {
      var now = day;
      final s = fixture();
      await open(t, s, now: () => now);
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      final timer = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      final id = timer.recordId;
      now = now.add(const Duration(minutes: 2));
      timer.refresh();
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await settings(t);
      await tap(t, find.byKey(const ValueKey('language-en')));
      await tap(t, find.byKey(const ValueKey('appearance-dark')));
      await closeSettings(t);
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      final resumed = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      expect(resumed, same(timer));
      expect(resumed.recordId, id);
      expect(resumed.remaining, const Duration(minutes: 23));
      expect(resumed.isRunning, isTrue);
      expect(s.decode(s.data).growth.records, isEmpty);
      await t.tap(find.text('End session'));
      await t.pumpAndSettle();
      expect(find.text('End focus session?'), findsOneWidget);
      await t.tap(find.text('Keep focusing'));
      await t.pumpAndSettle();
      expect(timer.isRunning, isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Natural completion while end confirmation is open closes it and records once',
    (t) async {
      var now = day;
      final store = fixture(language: 'en');
      await open(t, store, now: () => now);
      await tap(t, find.byKey(const ValueKey('home-start-study')));
      final timer = t.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      await t.tap(find.text('End session'));
      await t.pumpAndSettle();
      now = now.add(const Duration(minutes: 25));
      timer.refresh();
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Did you finish a topic?'), findsOneWidget);
      expect(store.decode(store.data).growth.records, hasLength(1));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'English forms, pickers, schedule and guide translate UI without changing subject text',
    (t) async {
      final s = fixture(language: 'en');
      await open(t, s);
      final before = jsonEncode(
        s.decode(s.data).subjects.map((v) => v.toJson()).toList(),
      );
      await t.tap(find.text('Study'));
      await t.pumpAndSettle();
      expect(find.text('All your subjects in one place'), findsOneWidget);
      await tap(t, find.text('Add subject'));
      expect(find.text('Subject name'), findsOneWidget);
      await tap(t, find.text('Choose exam date'));
      expect(
        Localizations.localeOf(t.element(find.byType(DatePickerDialog)))
            .languageCode,
        'en',
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await t.tap(find.text('Schedule'));
      await t.pumpAndSettle();
      expect(find.text('Plan today. Leave room for tomorrow.'), findsOneWidget);
      await t.tap(find.byTooltip('How Growza works'));
      await t.pumpAndSettle();
      expect(
        find.text('Grow your progress, one topic at a time.'),
        findsOneWidget,
      );
      expect(
        jsonEncode(s.decode(s.data).subjects.map((v) => v.toJson()).toList()),
        before,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Local account form validates fields without email reset or plaintext study credentials',
    (t) async {
      await t.binding.setSurfaceSize(const Size(392, 850));
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(392, 850);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      addTearDown(() => t.binding.setSurfaceSize(null));
      final s = fixture(language: 'en');
      final before = s.data;
      final accounts = InvalidLocalLogin();
      addTearDown(accounts.dispose);
      await open(t, s, accounts: accounts);
      await settings(t);
      await tap(t, find.byKey(const ValueKey('settings-account')));
      expect(find.byType(AuthScreen), findsOneWidget);
      await previews.capture(t, 'Interface-Sign-In-English');
      await tap(t, find.byKey(const ValueKey('auth-submit')));
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('auth-email')),
        'student@example.com',
      );
      await t.enterText(
        find.byKey(const ValueKey('auth-password')),
        'temporary-password',
      );
      await tap(t, find.byKey(const ValueKey('auth-submit')));
      expect(find.byKey(const ValueKey('auth-notice')), findsOneWidget);
      expect(s.data.contains('temporary-password'), isFalse);
      await tap(t, find.byKey(const ValueKey('auth-switch')));
      expect(find.text('Confirm password'), findsOneWidget);
      await previews.capture(t, 'Interface-Create-Account-English');
      await t.enterText(find.byKey(const ValueKey('auth-password')), 'short');
      await t.enterText(
        find.byKey(const ValueKey('auth-confirmation')),
        'other',
      );
      await tap(t, find.byKey(const ValueKey('auth-submit')));
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('auth-switch')));
      expect(find.byKey(const ValueKey('auth-reset')), findsNothing);
      expect(
        find.text(
          'Local account on this device. No verification email or code.',
        ),
        findsNothing,
      );
      expect(jsonDecode(s.data)['subjects'], jsonDecode(before)['subjects']);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('AI unavailable flow keeps topics untouched and sends nothing', (
    t,
  ) async {
    final s = fixture(language: 'en');
    await open(t, s);
    await t.tap(find.text('Study'));
    await t.pumpAndSettle();
    final before = s.decode(s.data).subjects.first.parts.length;
    await tap(t, find.byTooltip('Options for Biology'));
    await t.tap(find.text('Suggest topics from PDF'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-unavailable')), findsOneWidget);
    expect(
      find.text(
        'No file or text has been sent. You will be asked before using the service.',
      ),
      findsOneWidget,
    );
    expect(s.decode(s.data).subjects.first.parts.length, before);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Settings and account fit narrow screens with large text in both languages',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 700));
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 700);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        t.platformDispatcher.clearTextScaleFactorTestValue();
        return t.binding.setSurfaceSize(null);
      });
      for (final language in ['ar', 'en']) {
        await open(t, fixture(language: language));
        await settings(t);
        expect(t.takeException(), isNull);
        await tap(t, find.byKey(const ValueKey('settings-account')));
        expect(t.takeException(), isNull);
        await tap(t, find.byKey(const ValueKey('auth-switch')));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets('Settings footer stays above Android navigation buttons', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(400, 820);
    t.view.padding = FakeViewPadding(bottom: 48);
    t.view.viewPadding = FakeViewPadding(bottom: 48);
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.view.resetPadding();
      t.view.resetViewPadding();
    });
    await open(t, fixture(language: 'en'));
    await settings(t);
    final footer = find.text('Your choices are saved automatically.');
    await t.scrollUntilVisible(
      footer,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await t.ensureVisible(footer);
    await t.pumpAndSettle();
    expect(t.getRect(footer).bottom, lessThanOrEqualTo(820 - 48));
    expect(t.takeException(), isNull);
  });
  testWidgets('Arabic subject names remain exact in the English interface', (
    t,
  ) async {
    final s = fixture(language: 'en');
    final w = s.decode(s.data);
    w.subjects.add(
      StudySubject('شجرة', day.add(const Duration(days: 1)), [
        const StudyPart(1, 'المواد', 25),
      ]),
    );
    s.data = s.encode(w);
    await open(t, s);
    expect(find.text('شجرة'), findsOneWidget);
    expect(find.text('Next · المواد'), findsOneWidget);
    final context = t.element(find.text('شجرة'));
    expect(
      tr(context, 'ابدأ: {0} · {1}', ['شجرة', 'المواد']),
      'Start: شجرة · المواد',
    );
    expect(s.decode(s.data).subjects.last.name, 'شجرة');
  });
}
