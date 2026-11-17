# Growza - PDF creation and botanical verification

Date: 17 November 2026

## Completed

- Inline PDF import in subject creation, add-topic and subject editing; the existing menu shortcut uses the same flow.
- Immediate local bookmark/page-heading extraction, then explicit preview consent before the existing AI request.
- Editable suggestions saved only with the form. Cancellation, network failure, retry and manual entry remain available.
- Duplicate-title filtering and source filename/page ranges for each imported topic.
- Transactional SQLite v1-to-v2 upgrade preserves IDs, completion, sessions, focus spans and timer metadata. Backup round-trips the optional topic source.
- Five botanical vector stages: small tapered seed at the soil, curved stems/branches, veined shaded leaves, moss and ivory blossoms. The mature crown is broader. Growth calculations are unchanged.
- Existing motion, reduced-motion and lifecycle/offscreen suspension retained. Drawing cost is bounded independently of actual completed-topic counts.
- Release build preparation refreshes native plug-in registration; the development-only integration_test plug-in is excluded. App ID, signing certificate and dependency lock remain unchanged.

## Verification

| Check | Result |
| --- | --- |
| Flutter Analyze | No issues |
| Complete Flutter suite | 200 passed |
| Complete Worker suite | 28 passed |
| npm dependency audit | 0 known vulnerabilities reported across 38 packages |
| Real PDF extraction | Bookmarks, page-heading fallback, no-text failure and size limit passed |
| Creation/review UI | Consent denial, retry, replacement, duplicate prevention, busy guards and late async result disposal passed |
| Suggestion editing | Duplicate titles rejected; Arabic page digits parsed; unwanted topics removed |
| SQLite migration | IDs, completed work, history, timer and original PDF links retained; integrity check passed |
| Arabic/English | Narrow/enlarged layouts passed |
| Plant rendering/motion | All stages, thumbnails, light/dark, reduced motion and lifecycle tests passed; screenshots visually reviewed |
| Android Release | Built; public Worker URL compiled; application ID and certificate verified |
| Live Worker health | ok=true, ready=true, ai=true |
| Live AI calls in this revision | None |
| Git commands / cloud deployment | None |

## Remaining physical checks

The phone was disconnected. Installation and upgrade on Moto G75, opening from the launcher icon, touch during full-screen recording, native file-picker behavior and physical animation performance are unverified for this revision. The earlier Motorola launcher pause-state issue is not claimed fixed by a source-only change. Use the isolated Verification package for destructive fixture tests; do not reset the student workspace or launcher data.

The current build emits forward-compatibility warnings from workmanager_android/Kotlin tooling. The present release succeeds; a future Flutter SDK upgrade needs a compatible plug-in migration. Desktop headless rendering is not a physical-device FPS measurement. PDF assistance remains bounded heading analysis, without OCR or full-document comprehension.

## Prepared files

- `output/android/Growza-Android.apk`: ARM64-targeted Release for Moto G75.
- `output/previews/Growza-Botanical-Stages-Light.png` and `Growza-Botanical-Stages-Dark.png`: actual app-renderer galleries.
- `output/pdf/Growza-Academic-Development-Report.pdf`: concise English black-and-white academic update.

The upload copy is synchronized separately without touching its Git metadata; APKs and private device backups stay excluded.

## Changed application and test files

- `lib/ai_topics_screen.dart`
- `lib/app_theme.dart`
- `lib/app_translations.dart`
- `lib/growza_guide.dart`
- `lib/main.dart`
- `lib/pdf_topic_import.dart`
- `lib/plant_visual.dart`
- `lib/study_data.dart`
- `lib/study_database.dart`
- `lib/subject_details.dart`
- `lib/subject_setup.dart`
- `lib/workspace_backup.dart`
- `test/botanical_gallery_test.dart`
- `test/interface_completion_test.dart`
- `test/local_services_ui_test.dart`
- `test/pdf_creation_flow_test.dart`
- `test/pdf_extraction_test.dart`
- `test/study_database_test.dart`
- `test/widget_test.dart`
- `test/fixtures/pdf/no-text.pdf`
- `test/fixtures/pdf/outlined-chapters.pdf`
- `test/fixtures/pdf/page-headings.pdf`
