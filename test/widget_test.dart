import 'package:flutter_localizations/flutter_localizations.dart';

import 'interface_test_helpers.dart' as settings;

import 'package:file_selector/file_selector.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart'
    show FileSelectorPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/focus_timer.dart';
import 'package:growza/main.dart';
import 'package:growza/schedule_view.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_ui.dart';

class _TestFileSelector extends FileSelectorPlatform {
  XFile? selection;
  List<XTypeGroup>? requestedTypes;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    requestedTypes = acceptedTypeGroups;
    return selection;
  }
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  await tester.tap(label == 'رجوع' ? find.byTooltip('رجوع') : find.text(label));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target.hitTestable(),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('New Home shows one invitation to add a first subject', (
    tester,
  ) async {
    await tester.pumpWidget(const GrowzaApp(showWelcome: false));
    expect(find.text('أضف مادتك الأولى'), findsOneWidget);
    expect(find.text('Quick Study · 25 د'), findsNothing);
    expect(find.byKey(const ValueKey('open-study-garden')), findsNothing);
    await tapLabel(tester, 'أضف مادتك الأولى');
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Focus timer pauses, resumes, counts completion and offers a break',
    (tester) async {
      var completed = 0;
      final timer = FocusTimer(
        focusLength: const Duration(minutes: 1),
        now: tester.binding.clock.now,
        onFocusCompleted: () => completed++,
      );
      addTearDown(timer.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: FocusScreen(
            timer: timer,
            topic: 'Practice',
            subject: 'General study',
          ),
        ),
      );
      expect(find.text('01:00'), findsOneWidget);
      await scrollTo(tester, find.text('ابدأ التركيز'));
      await tapLabel(tester, 'ابدأ التركيز');
      await tester.pump(const Duration(seconds: 10));
      await tapLabel(tester, 'إيقاف مؤقت');
      final paused = timer.remaining;
      await tester.pump(const Duration(seconds: 20));
      expect(timer.remaining, paused);
      expect(completed, 0);

      await tapLabel(tester, 'متابعة');
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(completed, 1);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('وقت الاستراحة'), findsOneWidget);
      expect(find.text('ابدأ الاستراحة'), findsOneWidget);

      await tapLabel(tester, 'ابدأ الاستراحة');
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(find.text('انتهت الاستراحة'), findsOneWidget);
      expect(completed, 1);
      timer.reset();
      await tester.pump();
      expect(find.text('01:00'), findsOneWidget);
      expect(find.text('ابدأ التركيز'), findsOneWidget);
    },
  );

  testWidgets('Schedule creates, edits and deletes a manual session', (
    tester,
  ) async {
    await tester.pumpWidget(
      GrowzaApp(showWelcome: false, timerNow: () => DateTime(2026, 11, 12, 10)),
    );
    await tapLabel(tester, 'الجدول');
    await tester.tap(find.byKey(const ValueKey('schedule-day-2026-11-13')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إضافة للجدول'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Review flash cards',
    );
    await tester.enterText(find.byType(TextFormField).last, '1');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('حفظ الجلسة'));
    await tapLabel(tester, 'حفظ الجلسة');

    final original = find.byTooltip('خيارات جلسة Review flash cards');
    await scrollTo(tester, original);
    final manualTile = find.ancestor(
      of: original,
      matching: find.byType(ScheduleSessionRow),
    );
    final start = find.descendant(
      of: manualTile,
      matching: find.text('ابدأ التركيز'),
    );
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('01:00'), findsOneWidget);
    await tapLabel(tester, 'إنهاء الجلسة');
    await settings.confirmEnd(tester);
    await tester.tap(original);
    await tester.pumpAndSettle();
    await tapLabel(tester, 'تعديل');
    await tester.enterText(
      find.byType(TextFormField).first,
      'Practice flash cards',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('حفظ الجلسة'));
    await tapLabel(tester, 'حفظ الجلسة');

    final edited = find.byTooltip('خيارات جلسة Practice flash cards');
    await scrollTo(tester, edited);
    await tester.tap(edited);
    await tester.pumpAndSettle();
    await tapLabel(tester, 'حذف');
    await tapLabel(tester, 'حذف الجلسة');
    expect(find.text('Practice flash cards · 1 د'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home remembers actual study activity and resumes its timer from the single progress card',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final storage = _MemoryStorage();
      final origin = DateTime(2026, 11, 12, 14);
      final firstTick = tester.binding.clock.now();
      DateTime now() =>
          origin.add(tester.binding.clock.now().difference(firstTick));
      storage.snapshot = storage.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('Calculus II', dayOffset(origin, 7), [
              const StudyPart(1, 'Integrals', 45),
            ]),
            StudySubject('Physics', dayOffset(origin, 8), [
              const StudyPart(1, 'Newton’s laws', 35),
            ]),
          ],
        ),
      );
      await tester.pumpWidget(
        GrowzaApp(showWelcome: false, timerNow: now, storage: storage),
      );
      await tester.pumpAndSettle();
      final hero = find.byKey(const ValueKey('home-progress-card'));
      expect(
        find.descendant(of: hero, matching: find.text('مقترحة لقرب اختبارها')),
        findsOneWidget,
      );
      expect(storage.decode(storage.snapshot!).recentSubjects, isEmpty);

      final recentPhysics = find.byKey(
        const ValueKey('current-subject-Physics'),
      );
      await scrollTo(tester, recentPhysics);
      await tester.tap(recentPhysics);
      await tester.pumpAndSettle();
      expect(find.text('كل المواد'), findsNothing);
      await scrollTo(tester, find.byKey(const ValueKey('home-start-study')));
      await tester.tap(find.byKey(const ValueKey('home-start-study')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FocusScreen>(find.byType(FocusScreen)).timer.isRunning,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      await tapLabel(tester, 'إيقاف مؤقت');
      final timer = tester.widget<FocusScreen>(find.byType(FocusScreen)).timer;
      final remaining = timer.remaining;
      expect(storage.decode(storage.snapshot!).recentSubjects, ['Physics']);

      await tapLabel(tester, 'رجوع');
      await tapLabel(tester, 'الرئيسية');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: hero, matching: find.text('Physics')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hero, matching: find.text('آخر مادة ذاكرتها')),
        findsOneWidget,
      );
      final resume = find.text('متابعة المؤقت');
      await scrollTo(tester, resume);
      expect(find.byKey(const ValueKey('featured-subject')), findsNothing);
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FocusScreen>(find.byType(FocusScreen)).timer,
        same(timer),
      );
      expect(timer.remaining, lessThanOrEqualTo(remaining));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        GrowzaApp(showWelcome: false, timerNow: now, storage: storage),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: hero, matching: find.text('Physics')),
        findsOneWidget,
      );
      expect(storage.decode(storage.snapshot!).focusCount, 0);
      final recentMath = find.byKey(
        const ValueKey('current-subject-Calculus II'),
      );
      await scrollTo(tester, recentMath);
      await tester.tap(recentMath);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('home-start-study')));
      await tester.tap(find.byKey(const ValueKey('home-start-study')));
      await tester.pumpAndSettle();
      expect(find.text('تغيير الجلسة؟'), findsOneWidget);
      await tapLabel(tester, 'تغيير الجلسة');
      await tapLabel(tester, 'لم أنهِ موضوعاً');
      expect(storage.decode(storage.snapshot!).recentSubjects, [
        'Calculus II',
        'Physics',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Manual subjects support repair, focus feedback and local reload',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(392, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final storage = _MemoryStorage();
      final firstTick = tester.binding.clock.now();
      final origin = DateTime(2026, 11, 10, 14);
      var jump = Duration.zero;
      DateTime now() => origin
          .add(tester.binding.clock.now().difference(firstTick))
          .add(jump);

      Future<void> addSubject(String name, String part, String minutes) async {
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), name);
        await tapLabel(tester, 'اختر موعد الاختبار');
        await tapLabel(tester, 'حسنًا');
        await tester.enterText(fields.at(1), part);
        await tester.enterText(fields.at(2), minutes);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('حفظ المادة'));
        await tapLabel(tester, 'حفظ المادة');
      }

      Future<void> review(String minutes) async {
        await scrollTo(tester, find.text('تغيّر وقتك؟'));
        await tapLabel(tester, 'تغيّر وقتك؟');
        await tester.enterText(find.byType(TextField).last, minutes);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('مراجعة التغييرات'));
        await tapLabel(tester, 'مراجعة التغييرات');
      }

      await tester.pumpWidget(
        GrowzaApp(showWelcome: false, timerNow: now, storage: storage),
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'أضف مادتك الأولى');
      await addSubject('Mathematics', 'Integration exercises', '40');
      expect(find.text('مقترحة لقرب اختبارها'), findsOneWidget);
      await tapLabel(tester, 'المواد');
      await tapLabel(tester, 'أضف مادة');
      await addSubject('Physics', 'Newton’s laws', '35');

      await tapLabel(tester, 'المواد');
      final physics = find.byKey(const ValueKey('study-subject-Physics'));
      final addPart = find.descendant(
        of: physics,
        matching: find.text('أضف موضوعاً'),
      );
      await scrollTo(tester, addPart);
      await tester.tap(addPart);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Extra practice',
      );
      await tester.enterText(find.byType(TextFormField).last, '25');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('حفظ الموضوع'));
      await tapLabel(tester, 'حفظ الموضوع');

      await tapLabel(tester, 'الرئيسية');
      await review('115');
      expect(find.text('راجع خطتك'), findsOneWidget);
      expect(storage.decode(storage.snapshot!).sessions, isEmpty);
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
      await tapLabel(tester, 'الجدول');
      expect(find.text('مساحة لالتقاط الأنفاس.'), findsOneWidget);

      await review('115');
      await scrollTo(tester, find.text('تطبيق التغييرات'));
      await tapLabel(tester, 'تطبيق التغييرات');
      expect(storage.decode(storage.snapshot!).sessions, hasLength(3));

      jump = const Duration(minutes: 46);
      await review('85');
      final extra = find.text('Physics · Extra practice · 25 د');
      await scrollTo(tester, extra);
      expect(find.textContaining('سيُزال موعد'), findsOneWidget);
      expect(storage.decode(storage.snapshot!).sessions, hasLength(3));
      await scrollTo(tester, find.text('تطبيق التغييرات'));
      await tapLabel(tester, 'تطبيق التغييرات');
      expect(storage.decode(storage.snapshot!).sessions.map((s) => s.topic), [
        'Integration exercises',
        'Newton’s laws',
      ]);

      final partTile = find.widgetWithText(
        ScheduleSessionRow,
        'Integration exercises',
      );
      final start = find.descendant(
        of: partTile,
        matching: find.text('ابدأ التركيز'),
      );
      await scrollTo(tester, start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 40));
      await tester.pumpAndSettle();
      expect(
        storage.decode(storage.snapshot!).subjects.first.completedCount,
        0,
      );
      await scrollTo(tester, find.byKey(const ValueKey('review-topic-1')));
      await tester.tap(find.byKey(const ValueKey('review-topic-1')));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'حفظ التقدم');
      expect(
        storage.decode(storage.snapshot!).subjects.first.completedCount,
        1,
      );

      await tapLabel(tester, 'رجوع');
      await tapLabel(tester, 'الرئيسية');
      await scrollTo(tester, find.byKey(const ValueKey('home-progress-card')));
      expect(find.text('برعم'), findsOneWidget);

      await tapLabel(tester, 'المواد');
      final physicsPlay = find.byTooltip('ذاكر Newton’s laws');
      await scrollTo(tester, physicsPlay);
      await tester.tap(physicsPlay);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 35));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'لم أنهِ موضوعاً');
      await tapLabel(tester, 'رجوع');
      await tapLabel(tester, 'المواد');
      await scrollTo(tester, find.byTooltip('خيارات الموضوع Newton’s laws'));
      await tester.tap(find.byTooltip('خيارات الموضوع Newton’s laws'));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'تعديل الموضوع');
      await tester.enterText(find.byType(TextFormField).last, '12');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('حفظ الموضوع'));
      await tapLabel(tester, 'حفظ الموضوع');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        GrowzaApp(showWelcome: false, timerNow: now, storage: storage),
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'المواد');
      await scrollTo(tester, find.text('التقدير: 12 د'));
      final workspace = storage.decode(storage.snapshot!);
      expect(workspace.focusCount, 2);
      expect(workspace.growth.records, hasLength(2));
      expect(workspace.growth.totalFocused, const Duration(minutes: 75));
      expect(workspace.subjects[1].completedCount, 0);
      expect(workspace.subjects[1].parts.first.minutes, 12);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Paused timer and its subject survive a complete widget reload', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final now = DateTime(2026, 11, 14, 12);
    storage.snapshot = storage.encode(
      StudyWorkspace(
        subjects: [
          StudySubject('Math', now.add(const Duration(days: 4)), [
            const StudyPart(1, 'Algebra', 25),
          ]),
        ],
        activeTimer: {
          'timer': {
            'focusMs': 1500000,
            'remainingMs': 840000,
            'phase': 'focus',
            'deadline': null,
          },
          'session': StudySession(
            'Math',
            'Algebra',
            now,
            25,
            partId: 1,
          ).toJson(),
        },
      ),
    );
    await tester.pumpWidget(
      GrowzaApp(showWelcome: false, storage: storage, timerNow: () => now),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('متابعة المؤقت'));
    await tapLabel(tester, 'متابعة المؤقت');
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('Algebra'), findsNothing);
    expect(find.text('Math'), findsOneWidget);
    await tapLabel(tester, 'إيقاف مؤقت');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      GrowzaApp(
        showWelcome: false,
        storage: storage,
        timerNow: () => now.add(const Duration(hours: 2)),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('متابعة المؤقت'));
    await tapLabel(tester, 'متابعة المؤقت');
    expect(find.text('14:00'), findsOneWidget);
    expect(storage.decode(storage.snapshot!).focusCount, 0);
  });

  testWidgets(
    'Overdue restored focus is counted once across subsequent launches',
    (tester) async {
      final storage = _MemoryStorage();
      final now = DateTime(2026, 11, 14, 12);
      storage.snapshot = storage.encode(
        StudyWorkspace(
          activeTimer: {
            'timer': {
              'focusMs': 1500000,
              'remainingMs': 1500000,
              'phase': 'focus',
              'deadline': now
                  .subtract(const Duration(minutes: 2))
                  .toUtc()
                  .toIso8601String(),
            },
            'session': StudySession(
              'Math',
              'Algebra',
              now.subtract(const Duration(minutes: 27)),
              25,
              partId: 1,
            ).toJson(),
          },
        ),
      );
      for (var launch = 0; launch < 2; launch++) {
        await tester.pumpWidget(
          GrowzaApp(showWelcome: false, storage: storage, timerNow: () => now),
        );
        await tester.pumpAndSettle();
        final workspace = storage.decode(storage.snapshot!);
        expect(workspace.focusCount, 1);
        expect(workspace.growth.records, hasLength(1));
        expect(workspace.growth.totalFocused, const Duration(minutes: 25));
        expect(workspace.sessions, hasLength(1));
        expect(workspace.sessions.single.completed, isTrue);
        expect(workspace.activeTimer!['timer']['phase'], 'rest');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('Invalid timer snapshot preserves saved subjects and progress', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final now = DateTime(2026, 11, 14, 12);
    storage.snapshot = storage.encode(
      StudyWorkspace(
        subjects: [
          StudySubject('Math', now.add(const Duration(days: 4)), [
            const StudyPart(1, 'Algebra', 25),
          ]),
        ],
        focusCount: 3,
        activeTimer: {
          'timer': {'phase': 'unknown'},
        },
      ),
    );
    await tester.pumpWidget(
      GrowzaApp(showWelcome: false, storage: storage, timerNow: () => now),
    );
    await tester.pumpAndSettle();
    final workspace = storage.decode(storage.snapshot!);
    expect(workspace.subjects.single.name, 'Math');
    expect(workspace.focusCount, 3);
    expect(workspace.activeTimer, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A PDF filename is optional and never fills the study parts', (
    tester,
  ) async {
    final originalSelector = FileSelectorPlatform.instance;
    final selector = _TestFileSelector();
    FileSelectorPlatform.instance = selector;
    addTearDown(() => FileSelectorPlatform.instance = originalSelector);
    await tester.pumpWidget(const GrowzaApp(showWelcome: false));
    await tapLabel(tester, 'أضف مادتك الأولى');
    await scrollTo(tester, find.text('اختر ملف PDF'));
    await tapLabel(tester, 'اختر ملف PDF');
    expect(selector.requestedTypes!.single.extensions, ['pdf']);
    selector.selection = XFile('lecture-notes.pdf');
    await tapLabel(tester, 'اختر ملف PDF');
    expect(find.text('lecture-notes.pdf'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      isEmpty,
    );
  });
}

class _MemoryStorage extends StudyStorage {
  String? snapshot;

  @override
  Future<StudyWorkspace> load() async =>
      snapshot == null ? StudyWorkspace() : decode(snapshot!);

  @override
  Future<void> save(String value) async => snapshot = value;
}
