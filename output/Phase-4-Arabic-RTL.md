# Growza - stage 4: Arabic and RTL

Completed 14 November 2026. Flutter Analyze: no issues. Flutter Test: all 74 tests passed (69 existing tests adapted to Arabic UI and five new language/direction tests).

The application uses Arabic (Saudi Arabia) and Flutter SDK Material, Cupertino and widget localizations. Home, Study, Schedule, focus, completion, garden, forms, planner review, discard dialogs, calendar management, validation, error feedback, guidance and local notification titles are Arabic. Existing subject names, topic text, IDs, source links and storage keys remain unchanged. General-study protocol values retain their stored identity while their labels are Arabic.

Directional padding, alignment, garden ordering, weekly navigation, timeline columns and the schedule action mirror correctly. Standard back/chevron icons follow RTL; the banner arrow mirrors explicitly. Clock digits and subscription URL entry remain LTR. Numeric inputs accept Arabic-Indic, Persian and western digits and normalize them for existing duration validation.

Bundled the unmodified Noto Naskh Arabic font from the installed Flutter engine, including its SIL Open Font License, with Roboto fallback. No network font dependency was added. Existing reminders receive a localized signature revision so reconciliation can replace old scheduled titles without changing reminder IDs.

Core changes: lib/main.dart; app_theme.dart; study_ui.dart; study_input.dart (new); all existing user-facing views, editors, calendar services and notifications; pubspec.yaml and lockfile; assets/fonts. Tests: existing UI assertions, shared font configuration and new test/arabic_rtl_stage4_test.dart.

Validation covers Arabic material date pickers, RTL navigation and weekly ordering, right-side timeline time, LTR URLs/clock, Arabic numeric entry, preserved subject identity and 320-pixel/1.6x long-name layouts. Arabic preview renders were visually inspected. Stage 5 follows separately; no cloud service was added.
