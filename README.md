# Growza

Flutter study planner: one plant per subject, direct focus timer, explicit topic completion, exam countdowns and a continuous garden. The application works offline without an account. Project: `D:/Growza`.

## Current delivery

- **Native persistence:** normalized SQLite study tables; one-time transactional migration retains the old JSON file, IDs, quality, focus spans and timer. External calendars already use a separate SQLite database. Web retains local storage.
- **Entry and settings:** register or sign in locally with email/password, or continue as guest. No Supabase, email code or internet connection is needed. Local accounts share the existing device study workspace. Three-dot settings retain Arabic/English/phone language and Auto/Light/Dark. RTL, long names and enlarged text are supported.
- **Backup:** system-picker export/import includes study data, cached calendars and settings, with version/content checks and merge/replace confirmation. Current values win merges; incompatible focus records reject the merge. Passwords/tokens/PDF bytes are excluded. Separate database commits have rollback for handled failures, not cross-database crash atomicity.
- **Local credentials:** separate SQLite account table; PBKDF2-HMAC-SHA256 password fingerprints (600,000 rounds, unique salt) and a remembered identity in secure storage. Passwords are never stored as text or exported. Logout returns to entry; account deletion removes the local credential identity only. Email recovery is unavailable. Account authentication remains on the device. The separate Cloudflare Worker uses installation credentials for optional AI; it receives no email/password. See server/SETUP.md for current deployment status.
- **Optional PDF suggestions:** local bookmarks or page-heading extraction; bounded text preview, explicit external-service consent, editable topic names/page ranges and confirmation before saving. Time is calculated locally. Unconfigured/offline services show a human unavailable state; manual study continues.

## Study rules

`lib/growth_rules.dart` centralizes the 240-minute account-wide daily growth cap, five-minute eligibility minimum, completion tolerance, quality percentages (100/60/25), relative stage fractions (0/5/20/50/100%) and PDF limits/estimates. Subject target is `max(300, sum(topic estimates) × 2.0)`; subjects without topics retain 1200 minutes. Actual focus time is recorded independently of quality and growth. No absence penalty; prior focus history remains valid.

Home recommends the nearest unfinished exam and offers direct start/resume. Pauses do not count as focus; Home, screen lock and process termination do not cancel the timer. Ending a session records time, then asks for quality and explicit topic completion. The unanswered review survives reopening. Achievements retain plants after exams; moving an exam forward restores the plant. Garden labels show the last study date.

## External calendars

Schedule + offers a manual study session or an optional external calendar. The external option opens the Blackboard link form directly, with preview and explicit connection. Once a calendar is connected, the existing calendar management link remains visible. Schedule accepts HTTPS/webcal iCalendar subscription URLs, previews events and caches them locally. Provider sign-in pages are not feeds. Local completion never submits work to the provider. Imported items close after their final calendar day passes; unfinished study-topic dots remain until explicit completion. Timed exams receive day-before, same-day and final-hour reminders; date-only exams omit the final-hour alert. Background updates and delivery follow OS scheduling. The nearest 60 reminders share one reconciled queue; titles follow the saved language.

## Setup and verification

Local accounts need no external setup. [server/SETUP.md](server/SETUP.md) describes the current Cloudflare Worker, OAuth setup, D1 migrations and Flutter endpoint. AI is active on the owner-confirmed Workers Free plan; no paid upgrade or credits were enabled. Two synthetic 40-page outline PDFs passed real inference, using 53.136 measured Neurons combined; the deployed AI binding also passed a separate production smoke test. See the latest activation checkpoint below. Local accounts and study SQLite are independent of the Worker.

Use `flutter analyze` and `flutter test`. Server tests: `npm.cmd test` from `server/` (Node 22.13+); includes real SQLite quotas and a Miniflare/workerd runtime test. Android platform fixtures live in `integration_test/local_platform_test.dart`; use only the isolated `GROWZA_VERIFICATION=true` package and `--no-uninstall`. The optional export fixture additionally requires `GROWZA_EXPORT_SMOKE=true` and interaction with the system document picker. Never run fixtures against the student's main app or clear its data.

Dependencies added across the persistence/account revisions: `cryptography 2.9.0` (Apache-2.0), PBKDF2 password fingerprints; `pdfrx 2.6.6` (MIT), local PDF extraction; `flutter_secure_storage 11.2.0` (BSD-3-Clause), encrypted login tokens. Existing `sqflite` handles SQLite. Android OS auto-backup is disabled to prevent restoring encrypted tokens without their device key; explicit file backup remains available. iOS bridge code is prepared but untested.

APK: `output/android/Growza-Android.apk`. Concise results: `output/Local-Service-Preparation.md`. Academic report: `output/pdf/Growza-Academic-Development-Report.pdf`. No Git/GitHub workflow is used.

Resume checkpoint: Moto G75 SQLite integrity and historical IDs/spans retained; native Home/Study/Schedule and bilingual appearance reviewed. Settings now respect the bottom system inset. Analyze clean; 153 Flutter tests and nine Worker tests passed. Physical lock/process-restart focus checks remain pending.

Local account revision: parameters are in `lib/password_hash.dart`; accounts use `growza-accounts.db` and are excluded from study-file backups. [Password-storage reference](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), [cryptography API](https://pub.dev/documentation/cryptography/latest/cryptography/Pbkdf2-class.html).

Local account checkpoint: Analyze clean; all 167 Flutter tests passed. An isolated native Moto G75 account test passed with production SQLite, secure storage and PBKDF2 parameters. Fixture credentials were deleted; the student workspace was not used.

Email/form correction: sign-in pages contain no local/prototype status labels. `email_validation.dart` checks common unquoted email syntax in both form and account persistence, without provider allowlists or claims that the mailbox exists. Analyze clean; 171 Flutter tests passed.

## Historical Cloudflare checkpoints — 15 November 2026

These checkpoints describe earlier states; the current active state is documented below.

Prepared a Worker without Supabase/auth endpoints. Native installation credentials are scoped to the exact HTTPS endpoint and stored separately in secure storage. Enrollment happens only on an explicit, consented AI request, with one retry after credential expiry. Daily limits are 3 AI attempts per installation, 10 per IP/network and 30 globally; public enrollment is separately limited. These identify installations, not verified users. Server D1 stores token hashes and quota metadata only. AI is deliberately disabled (`AI_ENABLED=false`).

Local checks: Analyze clean; all 181 Flutter tests passed. All 18 Worker tests passed, including the actual workerd entrypoint with D1 migrations. The D1 remote database was created and migrated. The authenticated Cloudflare MCP entry is registered globally in Codex; restart Codex to load it. Cloudflare skills hosted on GitHub were not installed because the project owner prohibits Git/GitHub. No optional beta `cf` CLI was installed; this project already has Wrangler. Live inference, inference quality, phone timer lifecycle and iOS remain separate pending checks.

Cloudflare delivery: `https://growza-api.growza-worker.workers.dev` is deployed and its HTTPS health is confirmed (`ok=true`, `ready=true`, `ai=false`). Remote D1 migrations and the server secret are configured. Disabled AI, disallowed-origin and removed-auth responses were verified. The updated Android APK includes the public endpoint via `--dart-define-from-file=config/services.json`; it was subsequently installed on Moto G75 with existing data retained. Use the define file on later Flutter runs/builds. No live inference or study synchronization was enabled.

## Native installation checkpoint — 15 November 2026

The Cloudflare-configured APK is installed on Moto G75. SQLite integrity, original study/account rows, focus history and the paused timer were retained. A guarded `integration_test/device_focus_app.dart` fixture exercised the production timer/storage UI in a separate package: running background/lock/process restart, stable paused state, one-tap Home resume, pause exclusion and one partial record after explicit end/reopen. It recorded 294.371 focus seconds and excluded a 26.671-second pause gap; no topics were completed. Native HTTPS health passed with AI disabled. No student focus data was changed. The verification package was removed and Growza reopened. Analyze and the final fixture analysis are clean; all 181 Flutter tests pass. These functional checks do not establish performance.

## Bounded PDF heading batches — 15 November 2026

The deployed Worker splits the existing consented headings preview into at most three Unicode-safe batches, validates/merges topics and retains original page numbers. One file consumes one of three installation attempts/day, while every planned model call is reserved atomically against global/network ceilings. Migration 0003 preserves old IDs and counts old quota rows as one call. Any failed/truncated batch rejects the whole result without automatic retries. This is headings processing, not full-document reading or OCR; splitting does not guarantee lower token use. The phone APK needs no update. AI remains disabled. Verification: 28 Worker tests (including two synthetic 40-page heading analyses with mock AI and real workerd/D1 weighted SQL), clean Flutter Analyze and 181 passing Flutter tests. Live inference/consumption remains pending.

## Live AI activation — 15 November 2026

AI is active on the existing Worker endpoint (`health: ok=true, ready=true, ai=true`). Version: `543ea78b-c31a-4b1b-9a39-1f9353b4ba59`. The existing Moto G75 APK needs no update. In a subject, choose **Suggest topics from PDF**, select the file, review/consent to the extracted headings, then review and confirm the suggested topics.

The same Worker handler, with isolated in-memory quotas and real inference, processed two synthetic 40-page PDFs with 40 outline entries each. Arabic: 40 exact headings/page markers, 12.516 seconds, 28.818 provider-reported Neurons. English: 40 exact headings/page markers, 7.442 seconds, 24.318 Neurons. Two calls/file; 53.136 Neurons combined. This validates these controlled outlines, not arbitrary student files, full-text reading, scans or native end-to-end AI operation. Usage varies by text/output.

`chat_template_kwargs.enable_thinking=false` avoids unnecessary reasoning for extraction. Existing quotas, parsing, consent and manual alternatives remain. The provider Free allocation is 10,000 Neurons/day (UTC), and no paid overages were enabled. A separate verification installation consumed one counted production call (959 ms); no phone installation attempt or student data was used. No quotas were waived.

Validation: clean Analyze, 181 Flutter tests, 28 Worker tests, dry-run and actual HTTPS AI response passed. An initial transient local workerd fetch failure passed both isolated and full-suite rechecks without changing runtime code. Only Worker request parameters/configuration and its existing parameter assertion changed. Academic report now includes the live activation measurements. SQLite, accounts, growth and synchronization are unchanged.

## Direct PDF creation and botanical revision - 17 November 2026

Choose a PDF directly while adding a subject or a topic. Local contents extraction opens the consent preview immediately; agreeing requests AI suggestions in the same form. Review/edit before Save. Cancellation, unavailable service and errors keep manual entry available. Duplicate titles are skipped, and each imported topic keeps its own PDF filename/page range. SQLite schema v2 preserves existing IDs, completion, focus history and timer state.

All five plant stages now share the botanical renderer with tapered seeds, soil/moss, curved branches, veined leaves and ivory blossoms. The approved flat forest and motion/reduced-motion rules remain.

Validation: Analyze clean; 200 Flutter tests and 28 Worker tests passed; npm reported zero known vulnerabilities among 38 audited packages. The ARM64-targeted Release APK is at `output/android/Growza-Android.apk`; the original application ID and signing certificate are retained. Worker health is ready with AI active; no live inference or deployment was performed in this revision. Phone installation, cold icon launch, touch, screen recording and physical performance remain pending.

Build the release with normal platform-tooling regeneration (omit `--no-pub` when switching between debug, integration and release builds):

```powershell
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=config/services.json
```

The current SDK filters development-only plug-ins in Release. Reusing stale generated registration can incorrectly reference `integration_test`. No dependency or Flutter SDK upgrade was required. Forward-compatibility warnings from `workmanager_android` remain a future SDK-migration consideration.

## Optional examination dates - 17 November 2026

Examination dates are optional in manual and PDF-assisted subject creation. A date may be added or removed later; date-only exams are allowed today. Undated subjects have no exam countdown, event or reminders and are not automatically harvested. Planning uses the selected study window without inventing a deadline.

Flutter Analyze is clean and all 208 Flutter tests passed. Historical SQLite schemas 1 and 2 upgrade to schema 3 with all table rows and foreign keys preserved; the exam column accepts SQL NULL. Removal cancels old reminders. JSON/backup round-trips, manual/PDF creation, recommendations and planning without an exam are covered.

The signed update was installed on Moto G75 and opened with the saved workspace visible. No test subjects were created in the student workspace. Full undated creation is covered by automated tests; on-device inspection ended when the phone relocked. The upload source was synchronized without Git commands.
