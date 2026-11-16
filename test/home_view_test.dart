import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/app_theme.dart';
import 'package:growza/home_view.dart';
import 'package:growza/study_data.dart';

void main() {
  testWidgets(
    'Current subjects remain available when switching to recent subjects and back',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(392, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final subjects = [
        for (final name in ['Biology', 'Physics', 'Calculus II', 'English'])
          StudySubject(name, DateTime(2026, 11, 20), [
            const StudyPart(1, 'Revision', 25),
          ]),
      ];
      StudySubject? opened;
      var viewedAll = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildGrowzaTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeSubjects(
                subjects: subjects,
                recentSubjects: [subjects[1], subjects[0]],
                studiedNames: const ['Physics', 'Biology'],
                onOpen: (subject) => opened = subject,
                onViewAll: () => viewedAll = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final subject in subjects) {
        expect(
          find.byKey(ValueKey('current-subject-${subject.name}')),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('current-subject-Physics')));
      expect(opened, same(subjects[1]));
      expect(
        tester.getTopLeft(find.text('Physics')).dy,
        tester.getTopLeft(find.text('Biology')).dy,
      );
      await tester.tap(find.text('عرض الكل'));
      expect(viewedAll, isTrue);
      expect(subjects, hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );
}
