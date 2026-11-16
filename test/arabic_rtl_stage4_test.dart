import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/main.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_input.dart';
import 'package:growza/calendar_screen.dart';
import 'package:growza/calendar_service.dart';
import 'package:growza/schedule_view.dart';
import 'package:growza/focus_screen.dart';

import 'frontend_completion_test.dart' as previews;
import 'study_flow_stage2_test.dart' as flow;

class _Store extends StudyStorage {
  late String data;
  @override
  Future<StudyWorkspace> load() async => decode(data);
  @override
  Future<void> save(String value) async {
    data = value;
  }
}

void main() {
  test(
    'Arabic, Persian and western digits retain their numeric value and cursor',
    () {
      expect(normalizeStudyDigits('٢٥ ۴۵ 60'), '25 45 60');
      final value = studyDigitsFormatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '٢٥',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(value.text, '25');
      expect(value.selection.baseOffset, 2);
    },
  );
  testWidgets('New-user forms and material pickers use Arabic and RTL', (
    t,
  ) async {
    await t.pumpWidget(const GrowzaApp(showWelcome: false));
    await t.pumpAndSettle();
    expect(find.text('أضف مادتك الأولى'), findsOneWidget);
    final ctx = t.element(find.text('أضف مادتك الأولى'));
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(Localizations.localeOf(ctx).languageCode, 'ar');
    await t.tap(find.text('أضف مادتك الأولى'));
    await t.pumpAndSettle();
    await flow.tap(t, find.text('اختر موعد الاختبار'));
    final picker = t.element(find.byType(DatePickerDialog));
    expect(Directionality.of(picker), TextDirection.rtl);
    expect(MaterialLocalizations.of(picker).cancelButtonLabel, 'الإلغاء');
    expect(find.text('الإلغاء'), findsOneWidget);
    await t.tap(find.text('الإلغاء'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(2), '٣٥');
    expect(
      t
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      '35',
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Long Arabic subjects fit RTL Home and focus while the clock stays LTR',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 700));
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        t.platformDispatcher.clearTextScaleFactorTestValue();
        return t.binding.setSurfaceSize(null);
      });
      final now = DateTime(2026, 11, 14, 10);
      final saved = _Store();
      const name = 'الرياضيات المتقدمة وتطبيقاتها في العلوم والهندسة';
      saved.data = saved.encode(
        StudyWorkspace(
          subjects: [
            StudySubject(name, DateTime(2026, 11, 20), [
              const StudyPart(1, 'التكامل والتفاضل وتطبيقاتهما', 25),
            ]),
          ],
        ),
      );
      final old = saved.decode(saved.data).subjects.single;
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture-root'),
          child: GrowzaApp(
            showWelcome: false,
            storage: saved,
            timerNow: () => now,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.getCenter(find.text('الرئيسية')).dx,
        greaterThan(t.getCenter(find.text('الجدول')).dx),
      );
      expect(find.byTooltip('مراحل النمو'), findsOneWidget);
      await previews.capture(t, 'Arabic-Home-Stage-4');
      await flow.tap(t, find.byKey(const ValueKey('home-start-study')));
      expect(find.byType(FocusScreen), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('focus-clock'))).textDirection,
        TextDirection.ltr,
      );
      expect(Directionality.of(t.element(find.text(name))), TextDirection.rtl);
      await previews.capture(t, 'Arabic-Focus-Stage-4');
      expect(saved.decode(saved.data).subjects.single.id, old.id);
      expect(saved.decode(saved.data).subjects.single.name, name);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Schedule places earlier weekdays and the time column on the right',
    (t) async {
      await t.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final now = DateTime(2026, 11, 14, 10);
      final saved = _Store();
      saved.data = saved.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('الفيزياء', DateTime(2026, 11, 14, 18), [
              const StudyPart(1, 'الموجات', 25),
            ]),
          ],
        ),
      );
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture-root'),
          child: GrowzaApp(
            showWelcome: false,
            storage: saved,
            timerNow: () => now,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('الجدول'));
      await t.pumpAndSettle();
      expect(
        t.getCenter(find.byKey(const ValueKey('schedule-day-2026-11-9'))).dx,
        greaterThan(
          t.getCenter(find.byKey(const ValueKey('schedule-day-2026-11-15'))).dx,
        ),
      );
      final ctx = t.element(find.byType(ScheduleView));
      final time = MaterialLocalizations.of(ctx).formatTimeOfDay(
        const TimeOfDay(hour: 18, minute: 0),
        alwaysUse24HourFormat: false,
      );
      expect(
        t.getCenter(find.text(time)).dx,
        greaterThan(t.getCenter(find.text('اختبار · الفيزياء')).dx),
      );
      expect(
        t
            .widget<Icon>(
              find.descendant(
                of: find.byTooltip('الأسبوع التالي'),
                matching: find.byType(Icon),
              ),
            )
            .icon!
            .matchTextDirection,
        isTrue,
      );
      await previews.capture(t, 'Arabic-Schedule-Stage-4');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Calendar sharing URLs remain LTR inside an Arabic RTL form', (
    t,
  ) async {
    final service = CalendarService(supported: true, background: false);
    addTearDown(service.dispose);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ar', 'SA'),
        supportedLocales: const [Locale('ar', 'SA')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: CalendarImportScreen(
          service: service,
          now: () => DateTime(2026, 11, 14),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('رابط مشاركة التقويم'), findsOneWidget);
    final editable = find.descendant(
      of: find.byType(TextFormField).at(1),
      matching: find.byType(EditableText),
    );
    expect(t.widget<EditableText>(editable).textDirection, TextDirection.ltr);
    expect(
      Directionality.of(t.element(find.text('رابط مشاركة التقويم').first)),
      TextDirection.rtl,
    );
    expect(t.takeException(), isNull);
  });
}
