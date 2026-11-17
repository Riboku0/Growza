import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/account_service.dart';
import 'package:growza/pdf_topic_import.dart';
import 'package:growza/pdf_topics.dart';
import 'package:growza/study_data.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/subject_setup.dart';
import 'package:growza/subject_details.dart';
import 'package:growza/workspace_backup.dart';

import 'local_services_ui_test.dart' as ui;

class Topics implements TopicProvider {
  int calls = 0;
  Object? error;
  Completer<List<SuggestedTopic>>? pending;
  List<SuggestedTopic> result = const [
    SuggestedTopic('Cells', 1, 2),
    SuggestedTopic('DNA', 3, 4),
  ];
  @override
  Future<List<SuggestedTopic>> suggest(PdfHeadings document) async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? result : pending!.future;
  }
}

const selection = StudyPdfSelection(
  'biology.pdf',
  PdfHeadings('[1] Cells\n[3] DNA', 8),
);
final now = DateTime(2026, 11, 17, 12);
Widget launch(Widget page, ValueChanged<StudySubject> saved) => ui.host(
  Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        child: const Text('Open'),
        onPressed: () async {
          final result = await Navigator.of(context)
              .push<StudySubject>(MaterialPageRoute(builder: (_) => page));
          if (result != null) saved(result);
        },
      ),
    ),
  ),
);
Future<void> open(
  WidgetTester t,
  Widget page,
  ValueChanged<StudySubject> saved,
) async {
  await t.pumpWidget(launch(page, saved));
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
}

Future<void> consent(WidgetTester t) async {
  await ui.tap(t, find.byKey(const ValueKey('ai-pick')));
  expect(find.byKey(const ValueKey('pdf-consent-preview')), findsOneWidget);
  await t.tap(find.text('أوافق وأرسل'));
  await t.pumpAndSettle();
}

void main() {
  test('PDF append keeps completed topics, file sources and monotonic topic IDs; repeated titles are skipped', () {
    final subject = StudySubject(
      'Biology',
      now,
      [
        const StudyPart(
          2,
          'Cells',
          25,
          completed: true,
          startPage: 1,
          endPage: 2,
          pdfName: 'old.pdf',
        ),
      ],
      id: 'stable-subject',
      nextPartId: 9,
      pdfName: 'old.pdf',
    );
    final result = appendPdfTopics(
      subject,
      PdfTopicDraft('new.pdf', [
        const SuggestedTopic(' cells ', 1, 2),
        const SuggestedTopic('DNA', 3, 4),
        const SuggestedTopic(' dna ', 5, 6),
      ]),
    );
    expect(result.id, subject.id);
    expect(result.parts.map((p) => p.id), [2, 9]);
    expect(result.nextPartId, 10);
    expect(result.parts.first.completed, isTrue);
    expect(result.parts.first.pdfName, 'old.pdf');
    expect(result.parts.last.pdfName, 'new.pdf');
    expect(result.parts.last.minutes, 8);
    final restored = WorkspaceBackup.parse(
      WorkspaceBackup.export(StudyWorkspace(subjects: [result])),
    );
    expect(restored.subjects.single.parts.last.pdfName, 'new.pdf');
    expect(
      restored.subjects.single.parts.first.markComplete().pdfName,
      'old.pdf',
    );
  });

  testWidgets(
    'New subject reads PDF immediately and saves reviewed topics without a placeholder manual chapter',
    (t) async {
      final provider = Topics();
      StudySubject? saved;
      await open(
        t,
        SubjectSetup(
          now: () => now,
          pdfPicker: () async => selection,
          topicProvider: provider,
        ),
        (s) => saved = s,
      );
      await t.enterText(find.byType(TextFormField).first, 'Biology');
      await ui.tap(t, find.text('اختر موعد الاختبار'));
      await t.tap(find.text('حسنًا'));
      await t.pumpAndSettle();
      await ui.tap(t, find.byKey(const ValueKey('ai-pick')));
      expect(provider.calls, 0);
      expect(saved, isNull);
      expect(find.byKey(const ValueKey('pdf-consent-preview')), findsOneWidget);
      await t.tap(find.text('أوافق وأرسل'));
      await t.pumpAndSettle();
      expect(provider.calls, 1);
      expect(find.text('DNA'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      await ui.tap(t, find.text('حفظ المادة'));
      expect(saved!.parts.map((p) => p.title), ['Cells', 'DNA']);
      expect(saved!.parts.every((p) => p.pdfName == 'biology.pdf'), isTrue);
      expect(saved!.pdfName, 'biology.pdf');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Add chapter filters existing titles and preserves the existing subject and exam',
    (t) async {
      final provider = Topics();
      StudySubject? saved;
      final subject = StudySubject(
        'Biology',
        now.add(const Duration(days: 6)),
        [
          const StudyPart(
            5,
            'Cells',
            25,
            completed: true,
            pdfName: 'earlier.pdf',
          ),
        ],
        id: 'subject-stable',
        nextPartId: 12,
        pdfName: 'earlier.pdf',
      );
      await open(
        t,
        SubjectSetup(
          now: () => now,
          subject: subject,
          pdfPicker: () async => selection,
          topicProvider: provider,
        ),
        (s) => saved = s,
      );
      await consent(t);
      expect(find.text('تجاوزنا 1 مواضيع مكررة.'), findsOneWidget);
      await ui.tap(t, find.text('حفظ الموضوع'));
      expect(saved!.id, subject.id);
      expect(saved!.exam, subject.exam);
      expect(saved!.parts.map((p) => p.id), [5, 12]);
      expect(saved!.parts.first.completed, isTrue);
      expect(saved!.parts.last.pdfName, 'biology.pdf');
      expect(saved!.pdfName, 'earlier.pdf');
    },
  );

  testWidgets(
    'Declining consent makes no request and keeps manual chapter entry available',
    (t) async {
      final provider = Topics();
      StudySubject? saved;
      final subject = StudySubject('Biology', now, []);
      await open(
        t,
        SubjectSetup(
          now: () => now,
          subject: subject,
          pdfPicker: () async => selection,
          topicProvider: provider,
        ),
        (s) => saved = s,
      );
      await ui.tap(t, find.byKey(const ValueKey('ai-pick')));
      await t.tap(find.text('إلغاء'));
      await t.pumpAndSettle();
      expect(provider.calls, 0);
      expect(saved, isNull);
      await t.enterText(find.byType(TextFormField).first, 'My chapter');
      await ui.tap(t, find.text('حفظ الموضوع'));
      expect(saved!.parts.single.title, 'My chapter');
      expect(saved!.parts.single.pdfName, 'biology.pdf');
    },
  );

  testWidgets(
    'AI failure exposes retry and manual entry without creating or overwriting topics',
    (t) async {
      final provider = Topics()..error = const AccountException('network');
      PdfTopicDraft? draft;
      await t.pumpWidget(
        ui.host(
          Scaffold(
            body: SingleChildScrollView(
              child: PdfTopicImport(
                provider: provider,
                pick: () async => selection,
                onChanged: (value) => draft = value,
              ),
            ),
          ),
        ),
      );
      await consent(t);
      expect(provider.calls, 1);
      expect(draft!.topics, isEmpty);
      expect(find.byKey(const ValueKey('ai-unavailable')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-send')), findsOneWidget);
      provider.error = null;
      await ui.tap(t, find.byKey(const ValueKey('ai-send')));
      await t.tap(find.text('أوافق وأرسل'));
      await t.pumpAndSettle();
      expect(provider.calls, 2);
      expect(draft!.topics, hasLength(2));
      expect(find.byKey(const ValueKey('ai-unavailable')), findsNothing);
    },
  );

  testWidgets(
    'Save and re-pick stay disabled during inference and late results do not outlive the form',
    (t) async {
      final provider = Topics()..pending = Completer<List<SuggestedTopic>>();
      final subject = StudySubject('Biology', now, []);
      await open(
        t,
        SubjectSetup(
          now: () => now,
          subject: subject,
          pdfPicker: () async => selection,
          topicProvider: provider,
        ),
        (_) {},
      );
      await ui.tap(t, find.byKey(const ValueKey('ai-pick')));
      await t.tap(find.text('أوافق وأرسل'));
      await t.pump();
      expect(provider.calls, 1);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const ValueKey('ai-pick')))
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'حفظ الموضوع'),
            )
            .onPressed,
        isNull,
      );
      await t.pumpWidget(const SizedBox.shrink());
      provider.pending!.complete(provider.result);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Changing the PDF after reviewed suggestions clears the previous suggestions before the new request',
    (t) async {
      final provider = Topics();
      PdfTopicDraft? draft;
      var count = 0;
      await t.pumpWidget(
        ui.host(
          Scaffold(
            body: SingleChildScrollView(
              child: PdfTopicImport(
                provider: provider,
                pick: () async => count++ == 0
                    ? selection
                    : const StudyPdfSelection(
                        'new.pdf',
                        PdfHeadings('[1] Waves', 3),
                      ),
                onChanged: (value) => draft = value,
              ),
            ),
          ),
        ),
      );
      await consent(t);
      expect(draft!.topics, hasLength(2));
      await ui.tap(t, find.byKey(const ValueKey('ai-pick')));
      expect(draft!.fileName, 'new.pdf');
      expect(draft!.topics, isEmpty);
      await t.tap(find.text('إلغاء'));
      await t.pumpAndSettle();
      expect(provider.calls, 1);
      expect(find.text('DNA'), findsNothing);
    },
  );

  testWidgets(
    'Editing a subject can import PDF topics without dropping completed work or changing its ID',
    (t) async {
      final provider = Topics();
      StudySubject? saved;
      final subject = StudySubject('Biology', now, [
        const StudyPart(8, 'Earlier', 25, completed: true),
      ], id: 'stable');
      await open(
        t,
        SubjectDetails(
          subject: subject,
          existingNames: ['Biology'],
          pdfPicker: () async => selection,
          topicProvider: provider,
        ),
        (s) => saved = s,
      );
      await consent(t);
      await ui.tap(t, find.text('حفظ تفاصيل المادة'));
      expect(saved!.id, 'stable');
      expect(saved!.parts.first.completed, isTrue);
      expect(saved!.parts.map((p) => p.id), [8, 9, 10]);
      expect(saved!.pdfName, 'biology.pdf');
    },
  );

  testWidgets(
    'Reviewed suggestions reject duplicate names, accept Arabic page digits and remove unwanted topics',
    (t) async {
      final provider = Topics();
      PdfTopicDraft? draft;
      await t.pumpWidget(
        ui.host(
          Scaffold(
            body: SingleChildScrollView(
              child: PdfTopicImport(
                provider: provider,
                pick: () async => selection,
                onChanged: (value) => draft = value,
              ),
            ),
          ),
        ),
      );
      await consent(t);
      await ui.tap(t, find.text('Cells'));
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await t.enterText(fields.at(0), 'DNA');
      await t.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await t.pumpAndSettle();
      expect(find.text('يوجد موضوع بهذا الاسم بالفعل.'), findsOneWidget);
      await t.enterText(fields.at(0), 'Chromosomes');
      await t.enterText(fields.at(1), '٢');
      await t.enterText(fields.at(2), '٤');
      await t.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(draft!.topics.first.title, 'Chromosomes');
      expect(draft!.topics.first.startPage, 2);
      expect(draft!.topics.first.endPage, 4);
      expect(draft!.topics.first.minutes, 12);
      final unwanted = find.ancestor(
        of: find.text('DNA'),
        matching: find.byType(ListTile),
      );
      await ui.tap(
        t,
        find.descendant(of: unwanted, matching: find.byIcon(Icons.close)),
      );
      expect(draft!.topics.single.title, 'Chromosomes');
      expect(t.takeException(), isNull);
    },
  );

  for (final lang in ['ar', 'en']) {
    testWidgets(
      'Inline PDF consent and editable results fit narrow enlarged $lang layouts',
      (t) async {
        t.view.physicalSize = const Size(320, 760);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final provider = Topics();
        await t.pumpWidget(
          ui.host(
            Scaffold(
              body: SingleChildScrollView(
                child: PdfTopicImport(
                  provider: provider,
                  pick: () async => selection,
                  onChanged: (_) {},
                ),
              ),
            ),
            language: lang,
          ),
        );
        await ui.tap(t, find.byKey(const ValueKey('ai-pick')));
        expect(t.takeException(), isNull);
        await t.tap(find.text(lang == 'ar' ? 'أوافق وأرسل' : 'Agree and send'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Cells'), findsOneWidget);
      },
    );
  }
}
