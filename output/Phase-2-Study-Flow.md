# Growza - stage 2: study flow

Completed 14 November 2026. Flutter Analyze: no issues. Flutter Test: all 63 tests passed (57 previous and six new functional tests).

Home starts the last studied subject immediately. Current/recent subjects remain flat rows; selecting a row changes the main study selection without navigation. A new workspace has one first-subject invitation.

The focus screen shows the subject, time, centered plant, pause/resume and explicit end. Returning Home leaves focus running. Actual credited growth is previewed; the shared daily-cap message appears while time recording continues.

Ending focus saves time independently of topic completion, animates the plant and asks one topic question. Unanswered reviews survive reload. Completion actions remain visible with many topics. Breaks are optional and do not require a switch confirmation before new focus.

Files: lib/main.dart, home_view.dart, focus_screen.dart, session_completion.dart, plant_visual.dart, focus_timer.dart, study_storage.dart, study_ui.dart; test/study_flow_stage2_test.dart, widget_test.dart, frontend_completion_test.dart.

Validation includes partial sessions, automatic completion, no automatic topic checks, review restoration, cap feedback and 320-pixel layouts at 1.6x text scale. Focus and completion preview PNGs were visually reviewed. Stage 3 follows separately; Arabic/RTL and dark mode remain stages 4 and 5.
