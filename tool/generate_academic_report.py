from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from pypdf import PdfReader

output = Path("output/pdf/Growza-Academic-Development-Report.pdf")
pending = output.with_suffix(".pending.pdf")
title = ParagraphStyle("Title", fontName="Helvetica-Bold", fontSize=20, leading=25)
sub = ParagraphStyle("Sub", fontName="Helvetica", fontSize=9.5, leading=13)
heading = ParagraphStyle("Heading", fontName="Helvetica-Bold", fontSize=10.5, leading=14)
body = ParagraphStyle("Body", fontName="Helvetica", fontSize=9.2, leading=11.8)
cell = ParagraphStyle("Cell", fontName="Helvetica", fontSize=8.5, leading=10.5)
bold = ParagraphStyle("Bold", parent=cell, fontName="Helvetica-Bold")
def p(text, style=body):
    return Paragraph(text, style)
rows = [
("Stage", "Implementation", "Language and tools"),
("Project setup", "Configured Flutter for Android, iOS and web; moved and renamed the verified workspace to D:/Growza.", "Dart 3.13.2, Flutter 3.47.2, Dart Pub, PowerShell"),
("Phase 1<br/>Interface", "Built Home, Study and Schedule from the HTML prototype and UI report with manual study parts and optional PDF filename references.", "Dart, Flutter Material, file_selector"),
("Phase 2<br/>Study sessions", "Added focus/break timers, session editing, overlap checks and five garden growth stages.", "Dart Timer, Flutter Material, CustomPainter"),
("Phase 3<br/>Plan recovery", "Added single/bulk parts, effort estimates and review before fitting work into available time. Completed, manual and fixed sessions are protected.", "Dart scheduling logic, Flutter forms and date/time pickers"),
("Phase 3<br/>Progress and storage", "Separated timer and part completion. Confirmed parts grow plants. Local data includes progress and timer state; running timers use deadlines and paused timers retain remaining time.", "Dart JSON, path_provider, browser local storage"),
("Phase 4<br/>External calendars", "Added HTTPS/webcal subscription previews, time zones, recurrence and local completion. Classes reserve planner time; event types are correctable.", "Dart, HTTP, enough_icalendar, rrule, timezone, SQLite"),
("Phase 4<br/>Reminders", "Added background refresh, calendar-change alerts and separate calendar controls. Manual exams receive day-before, same-day and optional final-hour reminders. Date edits and deletion reconcile one queue.", "Workmanager, flutter_local_notifications, flutter_timezone, sqflite"),
("UI revision<br/>Theme and schedule", "Applied shared Material 3 styling and a daily timeline with weekly navigation. Selected dates use green numerals without a filled tile. Imported items become locally complete after their calendar day ends; their pending dots clear.", "Dart, Flutter Material 3, ThemeData, flutter_test"),
("Home revision<br/>Landscape and subjects", "Retained current/recent subjects as flat rows. Added an original forest banner and continuous animated garden with larger plants, grass and terrain. Study history persists locally.", "Dart, Flutter CustomPainter, ImageGen, bundled PNG asset"),
("Frontend<br/>Local flows", "Renamed project/app to Growza. Added icons, launch screens, guidance, search, subject/PDF-reference editing, part deletion and discard protection. Renaming preserves linked data; deleted part IDs are not reused.", "Dart, Flutter forms, local JSON, SVG, Python/Pillow, flutter_test"),
]
table = Table([[p(value, bold if i == 0 or j == 0 else cell) for j, value in enumerate(row)] for i, row in enumerate(rows)], colWidths=[82, 268, A4[0]-96-350], repeatRows=1)
table.setStyle(TableStyle([
("VALIGN",(0,0),(-1,-1),"TOP"), ("LEFTPADDING",(0,0),(-1,-1),6), ("RIGHTPADDING",(0,0),(-1,-1),6),
("TOPPADDING",(0,0),(-1,-1),3.5), ("BOTTOMPADDING",(0,0),(-1,-1),3.5),
("BOX",(0,0),(-1,-1),0.45,colors.black), ("INNERGRID",(0,0),(-1,-1),0.35,colors.black),
]))
def footer(canvas, document):
    canvas.setStrokeColor(colors.black)
    canvas.setLineWidth(0.45)
    canvas.line(48, 47, A4[0]-48, 47)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(48, 33, "GROWZA | MOBILE APPLICATION DEVELOPMENT")
    canvas.drawRightString(A4[0]-48, 33, str(document.page))
story = [
p("Growza Development Report",title),
p("Previous UI baseline | Phases 1-4 | 14 November 2026",sub), Spacer(1,11),
p("1. Objective",heading),
p("Help students choose feasible study work before examinations and track deadlines from their course calendars."),
Spacer(1,9), p("2. Implementation",heading), Spacer(1,4), table, Spacer(1,9),
p("3. Verification",heading),
p('Prior UI baseline: Flutter Analyze reported no issues. All 39 automated tests passed. Coverage includes exam changes and reminder cancellation, date-only alerts, timer restoration, exactly-once completion, bulk entry, linked renaming, deletion, midnight rollover, discard protection and narrow layouts at 1.6x text scale. Native Android integration passed on Moto G75, covering SQLite persistence, manual/imported alarm reconciliation, visible notifications and background work. That baseline APK was installed; its existing workspace hash was preserved.'),
Spacer(1,7), p("4. Current scope",heading),
p("The frontend uses local data. Refresh and notification delivery follow operating system scheduling. Date-only exams omit final-hour alerts; the nearest 60 pending reminders are maintained. Timer completion is recovered on reopening; it does not mark a study part complete automatically. Calendar tests used controlled data; a university link is required for live Blackboard validation. iOS is configured but has not been tested on Apple hardware. PDF content analysis, AI assistance and cross-device accounts remain future work."),
Spacer(1,7),
p('<b>References</b> &nbsp; Istudy-Design.html; Istudy-UI-Report-English.pdf; UI Report.md; user-provided interface reference images; <link href="https://help.anthology.com/blackboard/student/en/getting-started/calendar.html" color="black">Blackboard calendar sharing documentation</link>.',cell),
]
growth_rows = [
("Rule", "Stage 1 implementation"),
("Daily growth", "240 credited focus minutes per local day, shared across subjects. Intervals crossing midnight are split. Additional time remains in statistics; topic completion continues."),
("Interrupted sessions", "Less than 5 minutes gives no stem growth. At least 5 minutes grows in proportion to active time. Pauses and breaks are excluded; interrupted time is retained."),
("Completion grace", "5% of planned duration, capped at 1 minute. Grace changes completion status and never adds unstudied minutes."),
("Plant stages", "Seed: 0; Sprout: 60; Plant: 240; Shrub: 600; Tree: 1200 cumulative credited minutes per subject. All thresholds and limits are defined in one configuration file."),
("Topics and absence", "Topic completion is a separate flower-progress ratio. Absence never removes growth. The model supplies resting/waking and exam harvest eligibility for later garden rendering."),
]
growth_table = Table([[p(value, bold if i == 0 or j == 0 else cell) for j, value in enumerate(row)] for i, row in enumerate(growth_rows)], colWidths=[106, A4[0]-96-106], repeatRows=1)
growth_table.setStyle(TableStyle([
("VALIGN",(0,0),(-1,-1),"TOP"), ("LEFTPADDING",(0,0),(-1,-1),7), ("RIGHTPADDING",(0,0),(-1,-1),7),
("TOPPADDING",(0,0),(-1,-1),6), ("BOTTOMPADDING",(0,0),(-1,-1),6),
("BOX",(0,0),(-1,-1),0.45,colors.black), ("INNERGRID",(0,0),(-1,-1),0.35,colors.black),
]))
story += [
PageBreak(), p("Growth Logic: Stage 1", title),
p("Approved staged revision | 14 November 2026", sub), Spacer(1,12),
p("1. Objective and scope", heading),
p("Implement local focus-based growth before redesigning the study screens. This stage adds calculations, recorded focus intervals, persistence and migration; it adds no cloud integration."),
Spacer(1,10), p("2. Rules", heading), Spacer(1,5), growth_table,
Spacer(1,11), p("3. Implementation and data continuity", heading),
p("Dart models record active focus intervals and settle them on explicit end, reset or timer replacement. Returning Home or backgrounding the app does not cancel focus. Persistent record IDs prevent duplicate rewards after reload. Local subject IDs preserve links after renaming and separate a newly created subject from a deleted subject with the same name."),
Spacer(1,6),
p("Completed legacy sessions migrate once from their saved durations and scheduled dates, marked as legacy estimates. They follow the configured growth minimum and daily cap. Planned sessions and checked topics do not create focus minutes. Existing subjects, topics, completion flags, plans and counters remain intact. JSON growth-history schema version 1 stores the new records."),
Spacer(1,10), p("4. Files and tools", heading),
p("Core: lib/growth_rules.dart; focus_record.dart; growth_ledger.dart; local_id.dart. Integration: focus_timer.dart; study_storage.dart; study_data.dart; main.dart; subject_details.dart. Tests: test/growth_ledger_test.dart; focus_timer_test.dart; widget_test.dart.", cell),
Spacer(1,5),
p("Language and tools: Dart, Flutter, flutter_test, local JSON, PowerShell. Academic report: Python, ReportLab and pypdf; rendered with Poppler for visual verification.", cell),
Spacer(1,10), p("5. Verification and stage boundary", heading),
p("Flutter Analyze: no issues. Flutter Test: all 57 tests passed, including 18 new unit tests and the 39 existing tests. Coverage includes exact stage and five-minute boundaries, fractional time, shared caps, midnight splitting, pauses, breaks, grace, restore/replay, migration, subject identity and timed/all-day harvest eligibility."),
Spacer(1,6),
p("Stage 1 was completed and reported separately. Following the subsequent run request, its Android APK was built and installed on Moto G75. The installed workspace hash was preserved and saved subject identities and growth schema were verified. Subsequent study-flow, garden, Arabic/RTL and night-mode stages are documented on the following pages."),
]

story += [
PageBreak(), p("Study Flow and Garden", title),
p("Approved revision: Stages 2 and 3 | 14 November 2026", sub), Spacer(1,12),
p("1. Stage 2: direct study flow", heading),
p("Home starts the last studied subject with one tap. Current and recent subjects remain flat rows; selecting one changes the next study action without another screen. A new workspace has one first-subject invitation."),
Spacer(1,6),
p("The timer places time above a centered plant and shows a small subject name, pause/resume and explicit end. Home and backgrounding retain the timer. Growth previews use active intervals and the shared daily cap. The requested cap message appears while time recording continues."),
Spacer(1,6),
p("Ending focus saves time independently of topic completion. A brief plant animation accompanies one question with unfinished-topic choices. Only selected topics become complete. An unanswered review persists across reload, without duplicating focus credit. Breaks are optional; completion actions remain accessible with many topics."),
Spacer(1,11), p("2. Stage 3: exam context and garden", heading),
p("The existing forest banner combines exam days with a separate completed-topic progress bar. The continuous garden renders one plant per active subject: credited focus grows its stem and confirmed topics open flowers. Historical focus contributes to the same plant; inactivity never removes growth. The existing preview displays the five configured thresholds."),
Spacer(1,6),
p("A plant is harvested after a timed exam or after a date-only exam day ends. Harvested plants appear in an expandable Achievements section inside the garden. Subjects, topics, identities and focus history are retained. A future exam date restores the same plant. Date-dependent Home views refresh each minute while open and on resume."),
Spacer(1,11), p("3. Verification", heading),
p("Stage 2 checkpoint: Flutter Analyze reported no issues; all 63 tests passed, including six new functional tests. Stage 3 checkpoint: Analyze reported no issues; all 69 tests passed, including six additional countdown and garden tests."),
Spacer(1,6),
p("Tests cover direct start, partial focus, separate topic confirmation, retained review, shared-cap feedback, countdown boundaries, legacy growth versus flowers, harvest, date reactivation and data retention. Narrow 320-pixel layouts and long Arabic names were exercised at 1.6x text scale. Rendered Home, focus, completion and garden previews were inspected."),
Spacer(1,6),
p("The Android debug APK was built, verified as the existing Growza package and installed on Moto G75. The workspace SHA-256 was unchanged across installation. Launch succeeded; post-launch checks retained subjects, topics and historical focus IDs, with no Android or Flutter runtime errors observed."),
Spacer(1,11), p("4. Implementation and tools", heading),
p("New: focus_screen.dart, session_completion.dart, plant_visual.dart, exam_countdown.dart; study_flow_stage2_test.dart and garden_stage3_test.dart. Integration: main.dart, home_view.dart, study_garden.dart, focus_timer.dart, study_storage.dart, study_ui.dart and growza_guide.dart.", cell),
Spacer(1,5),
p("Dart, Flutter Material 3, CustomPainter, local JSON, flutter_test and PowerShell. Documentation: Python, ReportLab, pypdf and Poppler. Stage summaries are stored beside this report.", cell),
Spacer(1,11), p("5. Stage boundary", heading),
p("At this checkpoint, Arabic/RTL and dark mode remained for Stages 4 and 5. Their subsequent implementation is recorded on the next page. No cloud services were added."),
]
story += [
PageBreak(), p("Arabic, RTL and Night Mode", title),
p("Approved revision: Stages 4 and 5 | 14 November 2026", sub), Spacer(1,12),
p("1. Stage 4: Arabic interface and direction", heading),
p("The application uses Arabic (Saudi Arabia). Existing screens, forms, validation, planner review, calendar controls, guidance and notification titles are translated. Flutter SDK localizations provide Arabic Material/Cupertino controls, date/time pickers and accessibility labels."),
Spacer(1,6),
p("Directional spacing, alignment, plant ordering, weekly navigation and timeline columns follow right-to-left layout. Navigation arrows mirror appropriately; clock digits and subscription URL input remain left-to-right. Duration fields accept Arabic-Indic, Persian and western digits, normalizing them for the existing validation rules."),
Spacer(1,6),
p("Bundled Noto Naskh Arabic (SIL OFL) with Latin fallback supports offline typography. Subject names, topics, links, IDs and storage keys are preserved. Notification titles are reconciled in Arabic using existing reminder IDs."),
Spacer(1,11), p("2. Stage 5: persistent night appearance", heading),
p("A sun/moon button on Home and Study switches between light and warm green night palettes. The optional local darkMode value stores the user's choice. Missing/null values follow system brightness, preserving compatibility with old workspaces. No additional settings screen is required."),
Spacer(1,6),
p("All screens, fields, dialogs, garden and system bars use theme colors. Appearance changes retain the running timer, remaining time and record ID without settling focus."),
Spacer(1,11), p("3. Verification", heading),
p("Stage 4: Flutter Analyze reported no issues; all 74 tests passed, including five new language/direction tests. Stage 5: Analyze reported no issues; all 81 tests passed, including seven new appearance tests."),
Spacer(1,6),
p("Coverage includes Arabic pickers, RTL ordering, LTR URLs/clock, numeric entry, long names at 320 pixels and 1.6x text scale, legacy preference defaults, reload, system changes and active-focus continuity. Checked night text/action color pairs meet a 4.5:1 contrast threshold. Arabic and night Home, timer, completion and garden renders were visually reviewed."),
Spacer(1,11), p("4. Files, language and tools", heading),
p("New: study_input.dart, app_appearance.dart, arabic_rtl_stage4_test.dart, dark_mode_stage5_test.dart and bundled font/license assets. Integration: main.dart, app_theme.dart, study_storage.dart, study_ui.dart, plant_visual.dart and existing views, editors and calendar notification services.", cell),
Spacer(1,5),
p("Dart, Flutter Material 3, flutter_localizations, CustomPainter, local JSON, flutter_test and PowerShell. Report: Python, ReportLab, pypdf and Poppler. Stage summaries: Phase-4-Arabic-RTL.md and Phase-5-Night-Mode.md.", cell),
Spacer(1,11), p("5. Delivery and scope", heading),
p("All five approved local growth/UI stages are complete. The debug APK was installed and launched on Moto G75. The workspace hash was unchanged across installation; post-launch checks retained subjects, topics and historical focus identities, with no Android/Flutter runtime errors observed. Supabase, cloud synchronization, AI and PDF content analysis remain outside this revision."),
]
story += [
Spacer(1,8), p("6. Plant visual and motion pass", heading),
p("Approved flat forest B replaces the displayed photograph; the original asset is retained. One CustomPainter renders five plant stages, topic flowers and thumbnails. Home emphasizes the plant and direct start; shared headers, focus and stage previews use themed colors. Breathing, growth and celebration respect reduced motion and suspend when hidden. Growth rules, storage, timers and notification services are unchanged. No packages were added.", cell),
Spacer(1,4),
p("Dart/Flutter validation: Analyze clean; 90 tests passed. An isolated Moto G75 profile fixture measured Home 59.3 FPS (raster p95 12.78 ms) and focus 59.7 FPS (14.95 ms), over 12 seconds each. These short samples do not establish sustained performance; Apple hardware remains untested.", cell),
]
story += [
Spacer(1,8), p("7. Interface and preferences", heading),
p("Three-dot settings save Auto/Light/Dark and Phone/Arabic/English choices. Dart translations support RTL/LTR and preserve subject names. Home suggests the nearest unfinished exam. Focus confirmation/results retain existing rewards. Account and AI screens show unavailable states without sending credentials/files. No dependencies were added.", cell),
Spacer(1,4),
p("Analyze: clean; 101 tests passed, covering preferences, timer continuity, confirmation race, bilingual forms and narrow enlarged-text layouts. Controlled renders were reviewed. Installed on Moto G75 on 15 November: workspace hash, subjects/topics and historical focus IDs retained; launch logs clean. Lock/background checks remain pending. Main data remains local JSON; SQLite migration, Cloudflare, authentication and AI connection are deferred. Core growth changes await approval following automatic review.", cell),
]
story += [
PageBreak(), p("Approved Relative Growth", title),
p("Explicit user approval | 15 November 2026", sub), Spacer(1,12),
p("8. Approved relative growth revision", heading),
p("Dart/Flutter growth now uses the sum of topic estimates multiplied by 2.0, with a 300-minute minimum. Subjects without topics retain 1200 minutes. Named constants in growth_rules.dart define targets, stage fractions, quality, the five-minute minimum and the unchanged 240-minute daily budget."),
Spacer(1,9),
p("End-session quality scales plant credit to 100%, 60% or 25%; skipping uses 100%. Actual focus statistics, record IDs, time spans and topic flowers remain independent. The daily budget consumes actual eligible minutes before quality scaling. Missing quality in old JSON defaults to Full; existing focus history is retained. Editing topic estimates changes the target and stage, never the recorded minutes."),
Spacer(1,9),
p("A gentle streak counts local days with at least five actual focus minutes. Yesterday's streak remains available during today; a missed day resets the counter without removing growth. Home, focus, review and garden use the same relative stage calculation."),
Spacer(1,12), p("9. Calculus II preview", heading),
p("Illustrative topic estimates: 45 + 60 + 75 + 120 = 300 minutes. The target becomes 600 minutes. Five stages occur at 0, 30, 120, 300 and 600 credited minutes (0%, 5%, 20%, 50%, 100%). The preview reuses the production vector painter; it is not a screenshot of user data."),
Spacer(1,12), p("10. Validation and scope", heading),
p("Flutter Analyze: no issues. Flutter Test: all 122 tests passed, including 14 new unit tests and seven workflow tests. Cases cover both target boundaries, exact stages, partial/paused sessions, mixed-quality caps, midnight allocation, legacy defaults, invalid quality, target edits, streak gaps and pending-review replay. A separate five-stage rendering test also passed."),
Spacer(1,7),
p("No new packages, Git commands, SQLite migration, account integration or AI work. The timer implementation and unrelated services are unchanged. The growth APK was installed on Moto G75 on 15 November. Workspace bytes were unchanged during installation; post-launch subjects, topics, historical IDs, spans and quality values were retained. Legacy Full defaults were verified and runtime logs were clean. Visual and lifecycle checks remain pending; the phone was locked. Academic documentation uses Python, ReportLab, pypdf and Poppler."),
]
checks = __import__('json').loads(Path('tool/report_evidence/local-final-verification.json').read_text(encoding='utf-8'))
story += [
PageBreak(), p("Local Persistence and Service Preparation", title),
p("SQLite and optional service integration | 15 November 2026", sub), Spacer(1,12),
p("11. Local data and recovery", heading),
p("Native study data now uses normalized SQLite tables for subjects, topics, plans, focus records, focus spans and settings. Initial JSON migration and snapshot writes use transactions; the legacy file remains untouched. Stable identities, quality values, actual intervals, topic completion and timer snapshots are preserved. Web retains its local-storage adapter."),
Spacer(1,7),
p("Offline backup exports study data, cached external calendars and preferences to a JSON file through the system document picker. Import validates version and contents before merge or replacement. Existing values win merge conflicts; incompatible focus identities reject the merge. Study and calendar databases commit separately, with compensating rollback on handled failures; cross-database crash atomicity is not guaranteed. Credentials and PDF bytes are excluded."),
Spacer(1,11), p("12. Entry, account and optional PDF assistance", heading),
p("Cold entry offers sign-in, account creation and guest study. Connected sessions use secure token storage and refresh; passwords are not saved. A prepared Cloudflare Worker proxies Supabase Auth and provides recovery, logout and account deletion. Account deletion removes the remote identity only; local study data remains. No cloud synchronization or per-account study workspace isolation is implemented."),
Spacer(1,7),
p("PDF bookmarks, or bounded page headings, are extracted locally. External text transmission requires consent. Suggested topic names and page ranges remain editable until explicit confirmation; estimates are calculated locally at four minutes per page. Worker requests validate the account, input size, daily quotas and model output. Document text is treated as untrusted data. No cloud project was created or deployed; live email and AI remain unverified."),
Spacer(1,11), p("13. Verification", heading),
p(checks['validation']), Spacer(1,7), p(checks['native']),
Spacer(1,7), p(checks['delivery']),
Spacer(1,11), p("14. Files, language and tools", heading),
p("Key files: study_database.dart, study_storage_file.dart, workspace_backup.dart, backup_screen.dart, welcome_screen.dart, account_service.dart, auth_screen.dart, privacy_screen.dart, pdf_topics.dart, ai_topics_screen.dart, calendar services, main.dart and server/. Arabic/English layouts, language-aware reminders, last-study labels and brief harvest transitions are included.", cell),
Spacer(1,5),
p("Dart/Flutter, SQLite/sqflite, HTTP, Kotlin and Swift document-picker bridges; JavaScript/Cloudflare Worker with D1 quota SQL. Added pdfrx 2.6.6 (MIT) for local PDF extraction and flutter_secure_storage 11.2.0 (BSD-3-Clause) for tokens. Tests: flutter_test, native integration, SQLite FFI and Node test runner. Report: Python, ReportLab, pypdf and Poppler. Setup: server/SETUP.md. iOS remains untested. No Git commands were used.", cell),
]
local_auth = __import__('json').loads(Path('tool/report_evidence/local-auth-final-verification.json').read_text(encoding='utf-8'))
story += [
PageBreak(), p("Local Email and Password Accounts", title),
p("Approved local-only revision | 15 November 2026", sub), Spacer(1,12),
p("15. Scope and behaviour", heading),
p("The default account flow now registers and validates an email/password on the same device without Supabase, email verification codes or network requests. Registration signs in immediately. Logout returns to the entry screen; a later sign-in verifies the saved credentials. A remembered local session resumes after reopening while its account still exists. Earlier cloud-auth preparation is inactive in this flow. Sign-in pages use ordinary account wording without local/prototype labels; storage boundaries remain in privacy information. Shared form/storage email validation rejects malformed punctuation, whitespace, dot placement and domain labels, without provider restrictions or claims of mailbox existence."),
Spacer(1,9), p("16. Persistence and boundaries", heading),
p("A separate SQLite database stores account identity, normalized unique email, random salt, password fingerprint, work factor and algorithm. The original password is never stored. PBKDF2-HMAC-SHA256 uses 600,000 iterations, a 16-byte random salt and a 32-byte derived value. Derivation runs outside the mobile UI isolate; verification uses the library's constant-time byte comparison. Parameters are centralized in password_hash.dart."),
Spacer(1,7),
p("The remembered identity uses a dedicated secure-storage key. Credentials are excluded from study backups. Account creation, sign-in and logout are serialized; a late local sign-in cannot overwrite a subsequent logout. Deleting an account removes that credential identity and leaves study data intact."),
Spacer(1,7),
p("This is device-local identity, not proof of email ownership, a separate per-user study workspace or encryption of study data. Guest access remains available. The interface explains that all local identities use the same device workspace and that email recovery is unavailable. Local credentials are never sent as cloud AI authorization. No cloud project or synchronization was added."),
Spacer(1,11), p("17. Verification and delivery", heading),
p(local_auth['validation']), Spacer(1,7), p(local_auth['native']), Spacer(1,7), p(local_auth['delivery']),
Spacer(1,11), p("18. Files, language and tools", heading),
p("New Dart files: account_models.dart, local_account_store.dart, password_hash.dart and email_validation.dart. Integration: account_service.dart, auth_screen.dart, main.dart, settings_sheet.dart, privacy_screen.dart, ai_topics_screen.dart and app_translations.dart. Tests: local_account_test.dart, local_account_flow_test.dart, email_validation_test.dart and local_account_device_test.dart; existing account/UI tests were adjusted.", cell),
Spacer(1,5),
p("Tools: Flutter/Dart, SQLite/sqflite, flutter_secure_storage, compute isolates, flutter_test and Android integration. Added cryptography 2.9.0 (Apache-2.0) for maintained PBKDF2 and comparison primitives; existing study and growth rules are unchanged. Documentation: Python, ReportLab, pypdf and Poppler. References: OWASP Password Storage Cheat Sheet and the cryptography package API. No Git commands were used. iOS remains untested.", cell),
]
cloud = __import__('json').loads(Path('tool/report_evidence/cloudflare-final-verification.json').read_text(encoding='utf-8'))
story += [
PageBreak(), p("Cloudflare and Device Verification", title),
p("Pre-activation checkpoint | 15 November 2026", sub), Spacer(1,12),
p("19. Scope and data boundary", heading),
p("The Worker is independent of the device's email/password accounts and requires no Supabase. SQLite remains authoritative for subjects, topics, focus history and credential fingerprints. No study synchronization or PDF storage was added. The active service routes are health, installation enrollment and optional topic suggestions. Account-authentication and password-reset routes were removed from the Worker."),
Spacer(1,9), p("20. Transport and quotas", heading),
p("An installation receives a random 256-bit bearer token, valid for 30 days. D1 stores only its SHA-256 hash. Flutter stores the token under a separate secure-storage key scoped to the exact HTTPS endpoint, sharing concurrent enrollment and allowing one renewal/retry after rejection. Opening the app and local sign-in send nothing to the Worker. The existing preview and explicit consent precede heading-text transmission; neither PDF bytes nor account credentials are sent."),
Spacer(1,6),
p("Previewed headings are split into at most three balanced batches within the existing 12,000-character limit. Page numbers and Unicode are preserved. Each batch has at most 6,000 characters, 20 topics and 2,048 completion tokens. Validated results are merged and boundary duplicates combined. A file uses one of three installation attempts/day; all batch calls are reserved atomically against 30 global and 10 network calls/day. No automatic model retry occurs; any failed batch rejects the complete analysis. Legacy quota IDs remain, with old rows counting as one model call. Shared networks share limits; IP HMAC and expiry cleanup remain. AI stays disabled pending live evaluation."),
Spacer(1,9), p("21. Verification and deployment", heading),
p(cloud['validation']), Spacer(1,6), p(cloud['remote']), Spacer(1,6), p(cloud['delivery']),
Spacer(1,6), p(cloud['phone']),
Spacer(1,9), p("22. Development environment", heading),
p(cloud['mcp']),
Spacer(1,9), p("23. Files, language and tools", heading),
p("JavaScript Worker: index.js, worker.js and topic_chunks.js; SQL: 0002_installations.sql and 0003_model_call_budget.sql; Flutter/Dart: worker_ai_service.dart, secure_storage.dart, account_service.dart and AI consent/translations. Configuration and guide: wrangler.toml, package.json, SETUP.md; secret helper: scripts/set-ip-secret.mjs. Development tools: pinned Wrangler 4.162.0, Miniflare/workerd, Node test runner, SQLite, Flutter tests and HTTP mocks. workerd testing exposed and resolved invalid constant exports in the original Worker entrypoint. Native fixture: integration_test/device_focus_app.dart; host checks: Python/ADB. No Git commands were used.", cell),
Spacer(1,5),
p("References: developers.cloudflare.com/agent-setup/prompt.md; Workers AI pricing and Gemma 4 model documentation; official OpenAI MCP documentation. Candidate availability, live inference quality and provider limits require a separate activation check.", cell),
]


activation = __import__('json').loads(Path('tool/report_evidence/ai-activation-final.json').read_text(encoding='utf-8'))
live_rows = [("Synthetic outline PDF", "Pages / batches", "Exact headings", "Seconds", "Neurons")]
for item in activation['files']:
    live_rows.append(("Arabic Calculus" if item['name'] == 'calculus-ar' else "English Biology", f"{item['pages']} / {item['chunks']}", f"{item['exactOutlineMatches']} / 40", f"{item['elapsedMs']/1000:.3f}", f"{item['neurons']:.3f}"))
live_table = Table([[p(value, bold if row == 0 else cell) for value in values] for row, values in enumerate(live_rows)], colWidths=[151, 97, 94, 76, A4[0]-96-418], repeatRows=1)
live_table.setStyle(TableStyle([
    ("VALIGN",(0,0),(-1,-1),"TOP"), ("LEFTPADDING",(0,0),(-1,-1),6), ("RIGHTPADDING",(0,0),(-1,-1),6),
    ("TOPPADDING",(0,0),(-1,-1),7), ("BOTTOMPADDING",(0,0),(-1,-1),7),
    ("BOX",(0,0),(-1,-1),0.45,colors.black), ("INNERGRID",(0,0),(-1,-1),0.35,colors.black),
]))
story += [
PageBreak(), p("Live AI Activation and Evaluation", title),
p("Owner-confirmed Workers Free | 15 November 2026", sub), Spacer(1,12),
p("24. Deployment and scope", heading),
p("AI is active on the existing Growza Worker: health reports ok=true, ready=true and ai=true. The owner confirmed Workers Free; billing-read permission was unavailable. No plan upgrade or paid credits were enabled. Existing Android builds already contain the endpoint and require no reinstall. SQLite, account credentials, growth rules and study data are unchanged."),
Spacer(1,10), p("25. Inference configuration", heading),
p("The Gemma 4 26B A4B model uses JSON output and chat_template_kwargs.enable_thinking=false for bounded heading extraction. Temperature, completion limits, consent and quotas are retained. A small live comparison measured 40.731 seconds / 17.836 Neurons with default thinking versus 1.517 seconds / 1.491 Neurons with thinking disabled. These are individual observations, not latency guarantees."),
Spacer(1,10), p("26. Controlled two-document evaluation", heading),
p("Two synthetic 40-page PDFs were generated with 40 outline entries each. pypdf extracted Arabic Calculus and English Biology headings. The same Worker handler used isolated in-memory quota SQL and real Cloudflare REST inference. No student files or account credentials were transmitted."),
Spacer(1,7), live_table,
Spacer(1,7), p("Provider-reported usage totalled 53.136 Neurons across four calls. Both outputs preserved every fixture title and original page marker. Quotas for the phone were not consumed. These controlled outlines do not establish arbitrary PDF quality, native end-to-end AI operation, full-document comprehension or OCR. Text extraction remains bounded and suggestions require student review."),
Spacer(1,10), p("27. Production and regression verification", heading),
p("After deployment, a separate verification installation made one successful production AI-binding request: two correct page-linked topics in 959 ms. CORS denial and removed authentication routes remained correct. D1 contained one installation and one one-call analysis reservation, retained as counted usage. No quota was waived. Production inference usage was not returned to the public client."),
Spacer(1,6), p("Flutter Analyze: no issues. All 181 Flutter tests and 28 Worker tests passed; deployment dry-run passed. An initial local workerd fetch failed during concurrent startup; isolated and full-suite rechecks passed without changing runtime code. Changes: worker.js request parameters, its existing test assertion and wrangler.toml activation; guides and evidence were updated."),
Spacer(1,10), p("28. Free limits and tools", heading),
p("The current Free allocation is 10,000 Neurons/day at account level, resetting at UTC midnight; Free requests fail at exhaustion. Existing limits remain three file attempts per installation, at most three batches per file, 30 global and 10 network calls/day. Consumption varies by document and output. Tools: JavaScript, Cloudflare Worker/AI/D1, Wrangler, Node/SQLite, Flutter/Dart tests, Python, ReportLab, pypdf and Poppler. No Git commands were used.", cell),
Spacer(1,7), p('References: <link href="https://developers.cloudflare.com/workers-ai/platform/pricing/" color="black">Workers AI pricing</link>; <link href="https://developers.cloudflare.com/workers-ai/models/gemma-4-26b-a4b-it/" color="black">Gemma 4 model documentation</link>; <link href="https://ai.google.dev/gemma/docs/capabilities/thinking" color="black">Google Gemma thinking documentation</link>. Local evidence: ai-live-benchmark.json, ai-activation-production.json and ai-activation-final.json under tool/report_evidence/.', cell),
]

schedule_plus = __import__('json').loads(Path('tool/report_evidence/schedule-plus-final.json').read_text(encoding='utf-8'))
story += [
Spacer(1,9), p("29. Optional calendar entry in Schedule", heading),
p("Schedule + now offers a manual study session or an optional external calendar. The external option opens the existing Blackboard subscription-link form directly, retaining preview and explicit connection. Connected-calendar management remains available. Dismissing the menu changes nothing. Arabic/English labels and the existing theme are retained. No feed, reminder, completion, storage or AI rules changed.", cell),
Spacer(1,5), p(schedule_plus['validation'] + " The revised calendar-flow test verifies preview before connection; a new test covers dismissal and manual entry. The debug APK was installed and launched on Moto G75. Study/account SQLite and secure-storage files were preserved across installation. Files: main.dart, schedule_view.dart, app_translations.dart and four existing widget-test files. Dart/Flutter, flutter_test, Android/ADB and the existing PDF reporting tools. A real university feed was not supplied.", cell),
]

SimpleDocTemplate(str(pending), pagesize=A4, leftMargin=48, rightMargin=48, topMargin=38, bottomMargin=58, title="Growza Development Report",author="Growza Project").build(story,onFirstPage=footer,onLaterPages=footer)
pdf = PdfReader(pending)
assert len(pdf.pages) == 9, f"Expected nine pages, found {len(pdf.pages)}"
pending.replace(output)
print("Updated nine-page academic PDF with live AI evaluation.")

