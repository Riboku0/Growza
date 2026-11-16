import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/main.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';

class MemoryStorage extends StudyStorage {
  late String snapshot;
  @override
  Future<StudyWorkspace> load() async => decode(snapshot);
  @override
  Future<void> save(String value) async {
    snapshot = value;
  }
}

Future<void> tap(WidgetTester t, Finder target) async {
  await t.scrollUntilVisible(
    target.hitTestable(),
    140,
    scrollable: find.byType(Scrollable).first,
  );
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, String name) async {
  if (Platform.environment['GROWZA_CAPTURE_FRONTEND'] != '1') return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture-root')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('output/previews');
    await directory.create(recursive: true);
    await File('${directory.path}/Growza-$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      final path = File(
        'C:/src/flutter/bin/cache/artifacts/material_fonts/$name',
      );
      if (path.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(path.readAsBytesSync())),
        );
      }
    }
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });
  final now = DateTime(2026, 11, 14, 12);

  testWidgets(
    'Subject editing keeps sessions, history and a restored timer linked; part deletion never reuses an ID',
    (t) async {
      await t.binding.setSurfaceSize(const Size(392, 850));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final storage = MemoryStorage();
      storage.snapshot = storage.encode(
        StudyWorkspace(
          subjects: [
            StudySubject('Math', now.add(const Duration(days: 5)), [
              const StudyPart(1, 'Algebra', 25),
              const StudyPart(5, 'Old notes', 25, completed: true),
            ], pdfName: 'math.pdf'),
            StudySubject('Physics', now.add(const Duration(days: 6)), [
              const StudyPart(1, 'Waves', 25),
            ]),
          ],
          sessions: [
            StudySession(
              'Math',
              'Algebra',
              now.add(const Duration(hours: 2)),
              25,
              partId: 1,
            ),
            StudySession(
              'Math',
              'Old notes',
              now.subtract(const Duration(days: 1)),
              25,
              partId: 5,
              completed: true,
            ),
          ],
          recentSubjects: ['Math'],
          focusCount: 2,
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
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: storage, timerNow: () => now),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('المواد'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'missing');
      await t.pumpAndSettle();
      expect(find.text('لا توجد مواد تطابق بحثك.'), findsOneWidget);
      await t.tap(find.byTooltip('مسح البحث'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Algebra');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('study-subject-Physics')), findsNothing);
      await tap(t, find.byTooltip('خيارات Math'));
      await t.tap(find.text('تعديل المادة'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField), 'Physics');
      await tap(t, find.text('حفظ تفاصيل المادة'));
      expect(find.text('اختر اسماً آخر للمادة.'), findsOneWidget);
      await t.enterText(find.byType(TextFormField), 'Analysis');
      await tap(t, find.text('إزالة مرجع PDF'));
      await tap(t, find.text('حفظ تفاصيل المادة'));
      var workspace = storage.decode(storage.snapshot);
      expect(workspace.subjects.first.name, 'Analysis');
      expect(workspace.subjects.first.pdfName, isNull);
      expect(workspace.sessions.every((s) => s.subject == 'Analysis'), isTrue);
      expect(workspace.recentSubjects, ['Analysis']);
      expect(workspace.activeTimer!['session']['subject'], 'Analysis');
      await tap(t, find.byTooltip('خيارات الموضوع Algebra'));
      await t.tap(find.text('حذف الموضوع'));
      await t.pumpAndSettle();
      expect(find.text('أنهِ جلسة هذا الموضوع قبل حذفه.'), findsOneWidget);
      expect(
        storage.decode(storage.snapshot).subjects.first.parts,
        hasLength(2),
      );
      await tap(t, find.byTooltip('خيارات الموضوع Old notes'));
      await t.tap(find.text('حذف الموضوع'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'حذف الموضوع'));
      await t.pumpAndSettle();
      workspace = storage.decode(storage.snapshot);
      expect(workspace.subjects.first.parts.map((p) => p.id), [1]);
      expect(workspace.sessions.where((s) => s.completed).single.partId, 5);
      await tap(t, find.text('أضف موضوعاً'));
      await t.enterText(find.byType(TextFormField).first, 'New section');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await tap(t, find.text('حفظ الموضوع'));
      workspace = storage.decode(storage.snapshot);
      expect(workspace.subjects.first.parts.last.id, 6);
      expect(workspace.subjects.first.nextPartId, 7);
      await t.tap(find.text('الرئيسية'));
      await t.pumpAndSettle();
      await tap(t, find.text('متابعة المؤقت'));
      expect(find.text('14:00'), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Leaving a changed form asks before discarding and preserves the saved workspace',
    (t) async {
      await t.pumpWidget(const GrowzaApp(showWelcome: false));
      await tap(t, find.text('أضف مادتك الأولى'));
      await t.enterText(find.byType(TextFormField).first, 'Unfinished subject');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton).first);
      await t.pumpAndSettle();
      expect(find.text('تجاهل التغييرات؟'), findsOneWidget);
      await t.tap(find.text('متابعة التعديل'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Unfinished subject',
      );
      await t.tap(find.byType(BackButton).first);
      await t.pumpAndSettle();
      await t.tap(find.text('تجاهل'));
      await t.pumpAndSettle();
      expect(find.text('أضف مادتك الأولى'), findsOneWidget);
      expect(find.text('Unfinished subject'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Home, Study, Schedule, focus and forms fit a narrow screen with larger text',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 900));
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        t.platformDispatcher.clearTextScaleFactorTestValue();
        return t.binding.setSurfaceSize(null);
      });
      final storage = MemoryStorage();
      storage.snapshot = storage.encode(
        StudyWorkspace(
          subjects: [
            StudySubject(
              'Advanced mathematics and applications',
              now.add(const Duration(days: 5)),
              [
                const StudyPart(
                  1,
                  'Review differential equations and solve practice questions',
                  25,
                ),
              ],
            ),
          ],
        ),
      );
      await t.pumpWidget(
        GrowzaApp(showWelcome: false, storage: storage, timerNow: () => now),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.text('المواد'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await tap(
        t,
        find.byTooltip(
          'ذاكر Review differential equations and solve practice questions',
        ),
      );
      expect(find.text('25:00'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('رجوع'));
      await t.pumpAndSettle();
      await t.tap(find.text('الجدول'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('إضافة للجدول'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byType(BackButton).first);
      await t.pumpAndSettle();
      await t.tap(find.text('الرئيسية'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('كيف يعمل Growza'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(
        find.text('فهمت'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.text('فهمت'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Growza frontend preview', (t) async {
    await t.binding.setSurfaceSize(const Size(392, 850));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final storage = MemoryStorage();
    storage.snapshot = storage.encode(
      StudyWorkspace(
        subjects: [
          StudySubject('Calculus II', DateTime(2026, 11, 19, 10), [
            const StudyPart(1, 'Integration by parts', 25),
            const StudyPart(2, 'Practice questions', 25, completed: true),
            const StudyPart(3, 'Sequences and series', 25),
          ]),
          StudySubject('Biology', DateTime(2026, 11, 21), [
            const StudyPart(1, 'Cell structure', 25, completed: true),
          ]),
        ],
        recentSubjects: ['Calculus II'],
        sessions: [
          StudySession(
            'Calculus II',
            'Integration by parts',
            now.add(const Duration(hours: 2)),
            25,
            partId: 1,
          ),
        ],
      ),
    );
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture-root'),
        child: GrowzaApp(
          showWelcome: false,
          storage: storage,
          timerNow: () => now,
        ),
      ),
    );
    await t.pumpAndSettle();
    await capture(t, 'الرئيسية');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -480));
    await t.pumpAndSettle();
    await capture(t, 'Garden');
    await t.tap(find.text('المواد'));
    await t.pumpAndSettle();
    await capture(t, 'المواد');
    await t.tap(find.text('الجدول'));
    await t.pumpAndSettle();
    await capture(t, 'الجدول');
    expect(t.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Growza');
    expect(t.takeException(), isNull);
  });
}
