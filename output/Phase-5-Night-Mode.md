# Growza - stage 5: night mode

Completed 14 November 2026. Flutter Analyze: no issues. Flutter Test: all 81 tests passed (74 existing tests plus seven new appearance tests).

Home and Study expose one sun/moon button. The application follows system brightness until a manual choice; the selected light/dark value is saved locally as optional darkMode. Old workspaces without the field remain valid. No settings screen was added.

A shared warm green palette resolves text, surfaces, outlines, actions, semantic statuses, forms, date/time dialogs, menus, schedule, focus, completion, garden and system bars. The garden and plant ground adapt to night rendering. The forest banner retains readable white content. Light mode remains available.

Changing appearance preserves the current stateful Home, running timer, remaining time, pending review and growth history. Existing subjects and topic flags remain unchanged. No cloud service or growth rule was modified.

Files: lib/app_appearance.dart (new), app_theme.dart, main.dart, study_storage.dart, study_ui.dart, plant_visual.dart, study_garden.dart and existing view/editor theme-color references. Tests: test/dark_mode_stage5_test.dart (new). Documentation: README.md, output/Frontend-Status.md, this stage record, academic report generator and PDF.

Tests cover legacy preference defaults, JSON round-trip, saved-choice restoration, system brightness changes, manual override, text/action contrast (4.5:1 minimum for checked pairs), selected-state color, appearance changes during active focus, unchanged record IDs, session completion, topic flowers, dark date dialogs, RTL and 320-pixel/1.6x layouts. Night Home, focus, completion and garden renders were visually inspected.

Stages 1-5 are complete. Supabase, accounts, AI, PDF content extraction and cross-device synchronization remain outside this approved revision.

## Android deployment

The combined stage 4/5 Android debug build succeeded. Package com.example.istudy and label Growza were checked before installing on Moto G75. Installation and launch succeeded; workspace SHA-256 matched before and immediately after installation. Post-launch verification retained subject/topic data and historical focus IDs, with no Android or Flutter runtime errors observed. The refreshed output/android/Growza-Android.apk matches the installed build. New Arabic/night interactions were checked through the automated widget suite and rendered previews; the phone check verified launch and data continuity.
