import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/main.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';

class Memory extends StudyStorage {
  late String data;
  @override
  Future<StudyWorkspace> load() async => decode(data);
  @override
  Future<void> save(String value) async {
    data = value;
  }
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).first);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Exams follow the subject date, edits and deletion; bulk parts and completion persist',
    (t) async {
      await t.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final storage = Memory();
      storage.data = storage.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('Physics', DateTime(2026, 11, 20), [
              const StudyPart(1, 'Mechanics', 25),
            ]),
          ],
        ),
      );
      await t.pumpWidget(
        GrowzaApp(
          showWelcome: false,
          storage: storage,
          timerNow: () => DateTime(2026, 11, 14, 12),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('المواد'));
      await t.pumpAndSettle();
      await tap(t, find.byTooltip('خيارات Physics'));
      await tap(t, find.text('عرض الاختبار'));
      expect(find.text('اختبار · Physics'), findsOneWidget);
      await tap(t, find.text('اختبار · Physics'));
      await tap(
        t,
        find.text(
          MaterialLocalizations.of(t.element(find.byType(Scaffold).first))
              .formatFullDate(DateTime(2026, 11, 20)),
        ),
      );
      await t.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text(
            MaterialLocalizations.of(t.element(find.byType(DatePickerDialog)))
                .formatDecimal(21),
          ),
        ),
      );
      await t.tap(find.text('حسنًا'));
      await t.pumpAndSettle();
      await tap(t, find.text('حفظ الاختبار'));
      expect(
        storage.decode(storage.data).subjects.single.exam,
        DateTime(2026, 11, 21),
      );
      expect(find.text('اختبار · Physics'), findsOneWidget);
      await t.tap(find.text('المواد'));
      await t.pumpAndSettle();
      await tap(t, find.text('أضف موضوعاً'));
      await t.tap(find.text('عدة مواضيع'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Waves\nOptics');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await tap(t, find.text('حفظ الموضوع'));
      expect(
        storage.decode(storage.data).subjects.single.parts.map((p) => p.title),
        ['Mechanics', 'Waves', 'Optics'],
      );
      await tap(t, find.byTooltip('إكمال Waves'));
      expect(storage.decode(storage.data).subjects.single.completedCount, 1);
      await tap(t, find.byTooltip('إعادة فتح Waves'));
      expect(storage.decode(storage.data).subjects.single.completedCount, 0);
      await tap(t, find.byTooltip('خيارات Physics'));
      await t.tap(find.text('حذف المادة'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'حذف المادة'));
      await t.pumpAndSettle();
      expect(storage.decode(storage.data).subjects, isEmpty);
      await t.tap(find.text('الجدول'));
      await t.pumpAndSettle();
      expect(find.text('اختبار · Physics'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
