# Growza - stage 3: exam countdown, garden and harvest

Completed 14 November 2026. Flutter Analyze: no issues. Flutter Test: all 69 tests passed (63 previous and six additional tests).

- The existing forest banner now shows exam days alongside completed-topic progress. Days use calendar-date differences; timed and date-only cutoff semantics are preserved.
- The continuous garden renders one plant per active subject using credited active focus, including migrated historical sessions. Topic progress controls flowers separately. Stage names and growth minutes are visible. The existing preview shows the five configured thresholds from growth_rules.dart.
- Inactivity renders a resting plant without removing growth; beginning focus wakes it. No punishment or plant death was added.
- Past exams move their plants to an expandable Achievements section inside the same garden. Source subjects, topic flags, sessions, IDs and focus records remain intact. Editing the exam into the future restores that plant's growth.
- Current/recent Home rows retain active subjects; archived subjects remain in Study. An all-harvested workspace offers the next subject, without claiming it is a new user. Date-dependent Home content refreshes each minute while open and on app resume.
- Updated the existing in-app guide to explain focus growth and topic flowers accurately.

Files changed: lib/main.dart, home_view.dart, study_garden.dart, growza_guide.dart; test/widget_test.dart; README.md; output/Frontend-Status.md. New: lib/exam_countdown.dart; test/garden_stage3_test.dart. The shared lib/plant_visual.dart was introduced in stage 2 and is reused here.

Tests cover countdown and year/day boundaries, timed and all-day cutoff, legacy growth versus topic flowers, archived data retention, automatic harvest while Home stays open, exam reactivation, an all-harvested workspace, growth preview, long Arabic names and 320-pixel/1.6x layouts. Home, garden and completion PNGs were visually reviewed.

Academic record: tool/generate_academic_report.py; output/pdf/Growza-Academic-Development-Report.pdf. Languages and tools: Dart, Flutter Material 3, CustomPainter, local JSON, flutter_test; Python, ReportLab, pypdf and Poppler for the English black-and-white report.

Stage 4 (full Arabic/RTL), stage 5 (dark mode), Supabase and cloud synchronization have not been implemented.

## Android deployment

The combined stage 2/3 debug APK built successfully and replaced output/android/Growza-Android.apk. Package com.example.istudy and display name Growza were verified before installation. Installation on Moto G75 succeeded; the private workspace SHA-256 was unchanged across the update. The application launched successfully. Post-launch checks retained subjects, topics and historical focus IDs; no Android or Flutter runtime errors were observed. This is a launch/data-continuity smoke check; the new flows were verified by automated widget tests and rendered previews.
