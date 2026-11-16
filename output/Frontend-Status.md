# Growza development status - 14 November 2026

Latest interface completion: shared three-dot settings, saved three-way appearance/language, Arabic and English UI, deterministic study suggestion, end-session confirmation/result and account forms. Analyze clean; 101 tests passed. The APK was installed on Moto G75 on 15 November with workspace bytes preserved during installation and subject/topic/history checks passed; launch logs were clean. Notification Shade obscured the activity; full native lifecycle/reminder checks remain pending. No account, Cloudflare or AI request is sent. SQLite migration is pending; main subjects remain in local JSON. See Interface-Completion.md.

Growth-quality multipliers and relative goals remain pending explicit approval after automatic review rejected changes to core rewards/records during the UI scope. Their concrete proposal is in Pending-Growth-Changes.md.

Previous completed revision: **local stages 1-5 complete, followed by the approved flat-forest B visual/motion pass**. Each stage was validated independently: 57, 63, 69, 74 and 81 tests respectively. Flutter Analyze passed with no issues at each checkpoint.

Stage 4 completes Arabic (Saudi Arabia), RTL, localized pickers/notifications, Arabic numeric entry and bundled licensed typography. Stage 5 adds a saved sun/moon toggle, default system appearance, coordinated night colors and darker garden rendering. A running focus session survives appearance changes. Existing subject names, topic data, identities and focus history remain intact.

No Supabase or cloud synchronization has started. The prior stage 2/3 APK was installed on Moto G75 with a preserved workspace hash. The stage 4/5 debug APK was built, installed and launched on Moto G75. Its existing workspace SHA-256 was unchanged across installation. Post-launch checks retained subjects, topics and historical focus IDs; no Android/Flutter runtime errors were observed. The updated installer is output/android/Growza-Android.apk.

Details: Phase-1-Growth.md; Phase-2-Study-Flow.md; Phase-3-Garden.md; Phase-4-Arabic-RTL.md; Phase-5-Night-Mode.md.

Latest visual pass: one shared five-stage plant painter, larger Home plant, other-subject thumbnails, common header, improved themed drawing and reduced-motion-aware animation. Analyze passed; 90 tests passed. Moto G75 short profile samples: Home 59.3 FPS and focus 59.7 FPS. Main APK installed; workspace hash, subjects/topics and historical focus IDs preserved. Original photo retained. See Visual-Motion-Pass.md for files, metrics and limits.

At that visual-only checkpoint, the newer blueprint's recommendation, quality growth, relative goals and later backup/backend/AI work were not included. The latest interface pass above subsequently implements the recommendation.

Previous frontend revision:

Implemented and connected to local data:
- Home, current/recent subjects, progress banner, open garden and timer navigation.
- Study parts, single/bulk entry, editing, completion/reopening and confirmed subject/part deletion.
- Subject/PDF-reference editing, linked renaming, search, stable part IDs and retained completed-session history.
- Unsaved-change protection, in-app guidance, larger-text layouts and branded launch screens/icons.
- Subject exams derived automatically in Schedule; date/time editing and deletion stay synchronized.
- Manual exam reminders: day-before, same-day and optional final-hour alerts; date edits and subject deletion reconcile the shared queue.
- Running/paused timer persistence, elapsed-time recovery and exactly-once focus completion on reopening.
- Manual sessions, date/week navigation, study-plan review and imported calendar management.
- Selected dates use green numerals without background tiles. Prior-day imported items are complete locally, move to Done and lose pending dots; same-day overdue work stays pending until midnight.
- Loading, empty, validation and save-error feedback; PDF selection clearly records a filename only.

Previous revision validation: 39 automated tests passed; Flutter Analyze passed; Android debug APK built and installed on Moto G75. Native Android integration passed for SQLite persistence, manual/imported reminder reconciliation, visible notifications and background work. The existing study workspace SHA-256 was unchanged during the update.

Still required before a complete product release:
- Real university subscription validation and Apple-device testing.
- PDF content extraction/AI assistance, accounts and cross-device synchronization remain later work.

No backend service was added in this revision.
