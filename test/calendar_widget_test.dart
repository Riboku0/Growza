import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growza/calendar_data.dart';
import 'package:growza/calendar_feed.dart';
import 'package:growza/calendar_repository.dart';
import 'package:growza/calendar_service.dart';
import 'package:growza/calendar_screen.dart';
import 'package:growza/main.dart';
import 'package:timezone/data/latest.dart' as tzdata;

class _PreviewService extends CalendarService {
  _PreviewService()
    : super(
        supported: true,
        background: false,
        engine: CalendarEngine(
          repository: CalendarRepository(
            factory: databaseFactoryFfi,
            path: inMemoryDatabasePath,
          ),
          feed: CalendarFeed(
            client: MockClient(
              (request) async => http.Response(
                'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Test//EN\r\n'
                'BEGIN:VEVENT\r\nUID:essay\r\nDTSTAMP:20261101T000000Z\r\n'
                'DTSTART:20261112T150000Z\r\nSUMMARY:Essay submission\r\n'
                'END:VEVENT\r\nEND:VCALENDAR',
                200,
              ),
            ),
          ),
        ),
      ) {
    loading = false;
  }
  CalendarPreview? approved;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refreshIfNeeded() async {}
  @override
  Future<bool> subscribe(
    String name,
    String url,
    CalendarKind kind,
    CalendarPreview preview,
    bool reminders,
  ) async {
    approved = preview;
    sources = [CalendarSource(id: 1, name: name, url: url, kind: kind)];
    notifyListeners();
    return true;
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Schedule previews a calendar before explicit connection on a narrow screen',
    (tester) async {
      tzdata.initializeTimeZones();
      await tester.binding.setSurfaceSize(const Size(392, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _PreviewService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        GrowzaApp(
          showWelcome: false,
          calendars: service,
          timerNow: () => DateTime(2026, 11, 11, 10),
        ),
      );
      await _tap(tester, 'الجدول');
      expect(find.text('إضافة رابط تقويم'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('schedule-add')));
      await tester.pumpAndSettle();
      expect(service.sources, isEmpty);
      expect(service.approved, isNull);
      expect(find.text('إضافة جلسة مذاكرة'), findsOneWidget);
      await _tap(tester, 'إضافة جدول خارجي (اختياري)');
      expect(find.text('ألصق رابط تقويمك'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).last,
        'https://campus.example/ical',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('معاينة التقويم'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, 'معاينة التقويم');
      expect(find.text('راجع المواعيد المستوردة'), findsOneWidget);
      expect(find.text('Essay submission'), findsOneWidget);
      expect(service.approved, isNull);
      await tester.scrollUntilVisible(
        find.text('ربط التقويم'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, 'ربط التقويم');
      expect(service.approved!.items.single.title, 'Essay submission');
      expect(find.text('التقاويم · 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Schedule plus can be dismissed or open manual study without connecting a calendar',
    (tester) async {
      final service = _PreviewService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        GrowzaApp(
          showWelcome: false,
          calendars: service,
          timerNow: () => DateTime(2026, 11, 11, 10),
        ),
      );
      await _tap(tester, 'الجدول');
      await tester.tap(find.byKey(const ValueKey('schedule-add')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 40));
      await tester.pumpAndSettle();
      expect(find.text('إضافة جدول خارجي (اختياري)'), findsNothing);
      expect(service.sources, isEmpty);
      await tester.tap(find.byKey(const ValueKey('schedule-add')));
      await tester.pumpAndSettle();
      await _tap(tester, 'إضافة جلسة مذاكرة');
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text('ألصق رابط تقويمك'), findsNothing);
      expect(service.sources, isEmpty);
      expect(service.approved, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Past-day imports appear under Done and explain automatic completion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _PreviewService();
      addTearDown(service.dispose);
      service.items = [
        CalendarItem(
          id: 1,
          sourceId: 1,
          sourceName: 'Blackboard',
          uid: 'old',
          title: 'Yesterday assignment',
          start: DateTime(2026, 11, 13, 8),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ExternalCalendarsScreen(
            service: service,
            now: () => DateTime(2026, 11, 14, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('تم'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, 'تم');
      await tester.scrollUntilVisible(
        find.text('Yesterday assignment'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, 'Yesterday assignment');
      expect(find.text('اكتمل تلقائياً'), findsOneWidget);
      expect(find.text('جعله غير مكتمل'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
