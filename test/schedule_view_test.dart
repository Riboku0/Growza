import 'package:flutter_localizations/flutter_localizations.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/calendar_data.dart';
import 'package:growza/app_theme.dart';
import 'package:growza/schedule_view.dart';
import 'package:growza/study_data.dart';

void main() {
  final now = DateTime(2026, 11, 12, 13);
  final sessions = [
    StudySession(
      'Biology',
      'Cell structure review',
      DateTime(2026, 11, 12, 8),
      45,
      completed: true,
    ),
    StudySession(
      'Calculus II',
      'Integration by parts',
      DateTime(2026, 11, 12, 14),
      45,
    ),
    StudySession(
      'Biology',
      'Practice questions',
      DateTime(2026, 11, 12, 17),
      25,
    ),
    StudySession('Physics', 'Friday revision', DateTime(2026, 11, 13, 10), 30),
  ];
  final items = [
    CalendarItem(
      uid: 'lab',
      title: 'Physics lab',
      sourceName: 'University timetable',
      start: DateTime(2026, 11, 12, 10),
      end: DateTime(2026, 11, 12, 11, 30),
      deadline: false,
    ),
    CalendarItem(
      uid: 'essay',
      title: 'Submit chemistry assignment',
      sourceName: 'Blackboard',
      start: DateTime(2026, 11, 12, 18),
    ),
    CalendarItem(
      uid: 'reading',
      title: 'Reading notes due',
      sourceName: 'Blackboard',
      start: DateTime(2026, 11, 13),
      dateOnly: true,
    ),
  ];

  testWidgets(
    'Daily schedule selects dates and weeks and keeps imports in chronological order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      if (Platform.environment['ISTUDY_CAPTURE_SCHEDULE'] == '1') {
        final fonts = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
                ).readAsBytesSync(),
              ),
            ),
          )
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-bold.ttf',
                ).readAsBytesSync(),
              ),
            ),
          );
        await fonts.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          );
        await icons.load();
      }
      var day = DateUtils.dateOnly(now);
      CalendarItem? opened;
      DateTime? added;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildGrowzaTheme(),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: SafeArea(
                child: StatefulBuilder(
                  builder: (context, setState) => ScheduleView(
                    day: day,
                    now: now,
                    sessions: sessions,
                    calendarItems: items,
                    onDayChanged: (value) => setState(() => day = value),
                    onAdd: () => added = day,
                    onBack: () {},
                    onStart: (_) {},
                    sessionMenu: (_) => IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                    onCalendarItem: (item) => opened = item,
                    calendarCount: 1,
                    onCalendars: () {},
                  ),
                ),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 2,
                backgroundColor: scheduleCanvas,
                indicatorColor: scheduleSage,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'الرئيسية',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    label: 'المواد',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: 'الجدول',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cell structure review'), findsOneWidget);
      expect(find.text('Friday revision'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Cell structure review')).dy,
        lessThan(tester.getTopLeft(find.text('Physics lab')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Physics lab')).dy,
        lessThan(tester.getTopLeft(find.text('Integration by parts')).dy),
      );
      expect(tester.takeException(), isNull);
      if (Platform.environment['ISTUDY_CAPTURE_SCHEDULE'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('output/schedule-preview.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Physics lab'));
      expect(opened!.uid, 'lab');
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-11-13')));
      await tester.pumpAndSettle();
      expect(find.text('Friday revision'), findsOneWidget);
      expect(find.text('Reading notes due'), findsOneWidget);
      expect(find.text('Integration by parts'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Reading notes due')).dy,
        lessThan(tester.getTopLeft(find.text('Friday revision')).dy),
      );
      await tester.tap(find.byTooltip('إضافة للجدول'));
      expect(added, DateTime(2026, 11, 13));
      await tester.tap(find.byTooltip('الأسبوع التالي'));
      await tester.pumpAndSettle();
      expect(day, DateTime(2026, 11, 20));
      expect(find.text('مساحة لالتقاط الأنفاس.'), findsOneWidget);
      await tester.tap(find.text('اليوم'));
      await tester.pumpAndSettle();
      expect(day, DateUtils.dateOnly(now));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Schedule accommodates larger text and includes overnight classes on each occupied day',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildGrowzaTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: ScheduleView(
              day: now,
              now: now,
              sessions: const [],
              calendarItems: [
                CalendarItem(
                  uid: 'overnight',
                  title: 'Overnight study workshop',
                  start: DateTime(2026, 11, 11, 23),
                  end: DateTime(2026, 11, 12, 1),
                  deadline: false,
                ),
                CalendarItem(
                  uid: 'ended',
                  title: 'Previous class',
                  start: DateTime(2026, 11, 11, 22),
                  end: DateTime(2026, 11, 12),
                  deadline: false,
                ),
              ],
              onDayChanged: (_) {},
              onAdd: () {},
              onBack: () {},
              onStart: (_) {},
              sessionMenu: (_) => const SizedBox(),
              onCalendarItem: (_) {},
              onCalendars: () {},
              onAdjust: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Overnight study workshop'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Overnight study workshop'), findsOneWidget);
      expect(find.text('Previous class'), findsNothing);
      expect(find.text('جارٍ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('إضافة للجدول').hitTestable(), findsOneWidget);
    },
  );
  testWidgets(
    'Day dots disappear only after all unfinished work is completed and return when reopened',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var firstDone = false;
      var secondDone = false;
      var deadlineDone = false;
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildGrowzaTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                refresh = setState;
                return ScheduleView(
                  day: now,
                  now: now,
                  sessions: [
                    StudySession(
                      'Biology',
                      'First task',
                      DateTime(2026, 11, 12, 14),
                      25,
                      completed: firstDone,
                    ),
                    StudySession(
                      'Physics',
                      'Second task',
                      DateTime(2026, 11, 12, 15),
                      25,
                      completed: secondDone,
                    ),
                  ],
                  calendarItems: [
                    CalendarItem(
                      uid: 'homework',
                      title: 'Homework deadline',
                      start: DateTime(2026, 11, 12, 18),
                      done: deadlineDone,
                    ),
                  ],
                  onDayChanged: (_) {},
                  onAdd: () {},
                  onBack: () {},
                  onStart: (session) => setState(() {
                    if (session.topic == 'First task') {
                      firstDone = true;
                    } else {
                      secondDone = true;
                    }
                  }),
                  sessionMenu: (_) => const SizedBox.shrink(),
                  onCalendarItem: (_) => setState(() => deadlineDone = true),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dot = find.byKey(const ValueKey('schedule-pending-2026-11-12'));
      expect(dot, findsOneWidget);
      await tester.tap(find.text('First task'));
      await tester.pumpAndSettle();
      expect(dot, findsOneWidget);
      await tester.tap(find.text('Second task'));
      await tester.pumpAndSettle();
      expect(dot, findsOneWidget);
      await tester.ensureVisible(find.text('Homework deadline'));
      await tester.tap(find.text('Homework deadline'));
      await tester.pumpAndSettle();
      expect(dot, findsNothing);
      expect(find.text('First task'), findsOneWidget);
      refresh(() => deadlineDone = false);
      await tester.pumpAndSettle();
      expect(dot, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'A finished focus timer keeps its dot until the study part is confirmed complete',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var partDone = false;
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildGrowzaTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                refresh = setState;
                return ScheduleView(
                  day: now,
                  now: now,
                  sessions: [
                    StudySession(
                      'Biology',
                      'Open study part',
                      DateTime(2026, 11, 12, 14),
                      25,
                      partId: 1,
                      completed: true,
                    ),
                  ],
                  isSessionPending: (_) => !partDone,
                  calendarItems: const [],
                  onDayChanged: (_) {},
                  onAdd: () {},
                  onBack: () {},
                  onStart: (_) {},
                  sessionMenu: (_) => const SizedBox.shrink(),
                  onCalendarItem: (_) {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dot = find.byKey(const ValueKey('schedule-pending-2026-11-12'));
      expect(dot, findsOneWidget);
      expect(
        find.textContaining('انتهى التركيز · الموضوع مفتوح'),
        findsOneWidget,
      );
      refresh(() => partDone = true);
      await tester.pumpAndSettle();
      expect(dot, findsNothing);
      expect(find.text('Open study part'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Previous-day imports become Done and lose their dot at midnight',
    (tester) async {
      var clock = DateTime(2026, 11, 13, 12);
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildGrowzaTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                refresh = setState;
                return ScheduleView(
                  day: DateTime(2026, 11, 13),
                  now: clock,
                  sessions: const [],
                  calendarItems: [
                    CalendarItem(
                      uid: 'yesterday',
                      title: 'Yesterday assignment',
                      sourceName: 'Blackboard',
                      start: DateTime(2026, 11, 13, 15),
                    ),
                  ],
                  onDayChanged: (_) {},
                  onAdd: () {},
                  onBack: () {},
                  onStart: (_) {},
                  sessionMenu: (_) => const SizedBox.shrink(),
                  onCalendarItem: (_) {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dot = find.byKey(const ValueKey('schedule-pending-2026-11-13'));
      expect(dot, findsOneWidget);
      refresh(() => clock = DateTime(2026, 11, 14));
      await tester.pumpAndSettle();
      expect(dot, findsNothing);
      expect(find.text('Blackboard · تم'), findsOneWidget);
      expect(find.text('Yesterday assignment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
