import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:growza/ai_topics_screen.dart';
import 'package:growza/pdf_topics.dart';
import 'package:growza/pdf_topic_import.dart';
import 'package:growza/study_ui.dart';
import 'package:growza/backup_screen.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/privacy_screen.dart';

import 'frontend_completion_test.dart' as previews;

class FakeTopics implements TopicProvider {
  int calls = 0;
  @override
  Future<List<SuggestedTopic>> suggest(PdfHeadings document) async {
    calls++;
    return [const SuggestedTopic('Cells', 1, 3)];
  }
}

Future<void> tap(WidgetTester t, Finder target) async {
  await t.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await t.tap(target);
  await t.pumpAndSettle();
}

Widget host(Widget child, {String language = 'ar'}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildGrowzaTheme(),
  home: RepaintBoundary(key: const ValueKey('capture-root'), child: child),
);
void main() {
  test('Topic validation filters bad ranges/links, deduplicates and calculates estimates locally', () {
    final topics = SuggestedTopic.parse([
      {'title': 'Cells', 'startPage': 1, 'endPage': 3},
      {'title': 'Cells', 'startPage': 1, 'endPage': 3},
      {'title': 'http://bad', 'startPage': 1, 'endPage': 2},
      {'title': 'Wrong', 'startPage': 0, 'endPage': 2},
    ], 10);
    expect(topics, hasLength(1));
    expect(topics.single.minutes, 12);
  });
  testWidgets(
    'PDF sends only after consent; suggestions remain unsaved until explicit confirmation',
    (t) async {
      final provider = FakeTopics();
      PdfTopicDraft? result;
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<PdfTopicDraft>(
                    GrowzaRoute(
                      builder: (_) => AiTopicsScreen(
                        subject: 'Biology',
                        provider: provider,
                        pick: () async => const PdfHeadings('[1] Cells', 10),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('ai-pick')));
      expect(provider.calls, 0);
      expect(find.byKey(const ValueKey('pdf-consent-preview')), findsOneWidget);
      await t.tap(find.text('إلغاء'));
      await t.pumpAndSettle();
      expect(provider.calls, 0);
      await tap(t, find.byKey(const ValueKey('ai-send')));
      await t.tap(find.text('أوافق وأرسل'));
      await t.pumpAndSettle();
      expect(provider.calls, 1);
      expect(result, isNull);
      expect(find.text('Cells'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('ai-confirm')));
      expect(result!.topics.single.minutes, 12);
      expect(t.takeException(), isNull);
    },
  );
  for (final language in ['ar', 'en']) {
    testWidgets(
      'New backup, privacy and PDF flows fit narrow enlarged $language layouts',
      (t) async {
        t.view.physicalSize = const Size(320, 760);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        for (final screen in [
          AiTopicsScreen(
            subject: 'مادة عربية ذات اسم طويل جداً للقياس',
            pick: () async => null,
          ),
          BackupScreen(
            snapshot: () async => StudyWorkspace(),
            onApply: (_) async {},
            canImport: () => true,
          ),
          const PrivacyScreen(),
        ]) {
          await t.pumpWidget(host(screen, language: language));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await previews.capture(t, 'Local-${screen.runtimeType}-$language');
        }
      },
    );
  }
}
