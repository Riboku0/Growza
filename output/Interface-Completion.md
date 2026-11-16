# Interface completion - 14 November 2026

Three-dot settings now offer Auto/Light/Dark and Phone language/Arabic/English. The header is shared across Home, Study and Schedule; the close button stays visible while the panel scrolls. Two saved optional preferences preserve old workspaces: existing darkMode keeps its semantics; languageCode defaults to Arabic for legacy data, and null explicitly follows the device. User-entered subject/topic names are inserted verbatim.

Home uses nearest upcoming unfinished exam, then remaining-topic count, then stable input order; an explicit choice and active timer override the suggestion. The main button identifies the subject/topic. Focus end confirmation can be cancelled, and natural completion while the dialog is open closes it and settles once. The review displays existing-engine growth, partial-session status and the next fixed threshold without changing rewards.

Account forms cover sign-in, creation, reset, validation, password visibility and guest continuation. These are not connected accounts: they explicitly say unavailable and never save/transmit credentials or claim a successful login/reset. The optional PDF-topic panel likewise sends nothing and keeps manual topic entry available.

## Files

New: lib/app_strings.dart, app_translations.dart, app_preferences.dart, settings_sheet.dart, auth_screen.dart, ai_topics_screen.dart, study_recommendation.dart; test/interface_completion_test.dart and interface_test_helpers.dart.

Updated: main.dart, app_header.dart, study_storage.dart (language preference only), study_data.dart (localized date/general-study labels), study_ui.dart, home_view.dart, schedule_view.dart, calendar_screen.dart, study_garden.dart, plant_visual.dart, focus_screen.dart, session_completion.dart, exam_countdown.dart, exam_editor.dart, subject_setup.dart, subject_details.dart, session_editor.dart, plan_review.dart, form_guard.dart and growza_guide.dart. Existing UI tests were updated for settings, explicit locale and end confirmation.

## Validation and limits

Flutter Analyze: no issues. Flutter Test: 101 passed, including eleven additional tests for preferences, phone locale, recommendation, English forms/pickers/guide, preserved Arabic names, active-timer identity, confirmation race, account validation, unavailable AI and 320-pixel layouts at 1.6x text scale. Controlled phone-size renders were inspected; they are not device screenshots. The main Android APK was built and package-checked. The user disconnected the phone, so this revision was not installed, profiled or tested with native lock/background/notification delivery.

No new dependencies. Growth rules, ledger, focus records/timer, calendar services/notifications and platform workspace implementations were not changed. The notification engine remains as previously implemented; this pass translates its existing in-app messages, not the native alarm language/scheduling implementation. Prior device results are historical and do not verify this APK.

Main subjects still use local JSON; calendar subscriptions use their existing SQLite store. SQLite workspace migration, real email/password authentication, Cloudflare Worker, AI extraction/consent/response review and synchronization are later work. File backup, quality multipliers, relative plant goals/streak and harvest motion are not implemented by this interface pass. The growth proposal is recorded separately after automatic approval rejected core changes in the UI scope.

## Installation follow-up - 15 November 2026

Installed the verified main APK on Moto G75 with adb install -r. The workspace SHA-256 was unchanged across installation. Post-launch subjects/topics matched exactly, and all historical focus IDs remained. The app process launched with no AndroidRuntime/Flutter errors observed. Notification Shade covered the activity, so no screenshot or visual Home confirmation is claimed. Native lock/background/reminder checks were not rerun. No application code changed.
