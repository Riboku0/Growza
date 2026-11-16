# Growza - growth stage 1

Status: complete, stopped at the requested stage boundary.

## Implemented

- One configuration file: 240 growth minutes per local day across the workspace; a five-minute minimum; 5% completion grace capped at one minute; seed/sprout/plant/shrub/tree at 0/60/240/600/1200 credited minutes.
- Interrupted sessions below five minutes remain in time statistics. At five minutes or more, their actual focus time is eligible for proportional growth. Grace changes completion status, not credited duration.
- Active intervals exclude pauses and breaks. End/reset/switch settle a record; backgrounding and returning Home keep the session alive. Restoring a timer cannot repeat the same reward.
- Calendar-day splitting shares the cap across subjects. Reaching the cap exposes the requested message for the next UI stage; statistics and topic progress continue.
- Topic progress is separate from stem growth. Absence does not remove growth. Resting/waking and timed/all-day exam harvest eligibility are calculated without moving or deleting subjects.
- Existing completed focus sessions migrate once, using saved durations and dates marked as legacy estimates. Existing subjects, topics, completion flags, plans and counters are preserved. Existing sessions follow the same growth minimum and cap.
- Stable subject IDs preserve links after renaming and prevent reusing a deleted name from restoring the old plant or resetting its daily account budget.

## Files

New:
- lib/growth_rules.dart - all requested tunable values and stage definitions.
- lib/focus_record.dart - focus intervals and settled records.
- lib/growth_ledger.dart - statistics, shared cap, stages, topic ratio, resting and harvest calculations.
- lib/local_id.dart - persistent local identities.
- test/growth_ledger_test.dart - rule, cap, boundary, migration and identity tests.

Changed:
- lib/focus_timer.dart - active-time tracking, partial end, grace and restoration.
- lib/study_storage.dart - persisted history, one-time migration and subject growth queries.
- lib/study_data.dart - stable subject IDs carried through copies and JSON.
- lib/main.dart - connect the current timer to atomic history/count saves.
- lib/subject_details.dart - keep subject identity when renaming.
- test/focus_timer_test.dart - interruption, pause, grace and reload cases.
- test/widget_test.dart - verify persisted time and exactly-once completion in existing flows.
- README.md; output/Frontend-Status.md; output/Phase-1-Growth.md - scope and results.
- tool/generate_academic_report.py; output/pdf/Growza-Academic-Development-Report.pdf - academic implementation record.

## Verification

Flutter Analyze: no issues.
Flutter Test: 57 tests passed (39 existing tests plus 18 new unit tests).

The tests cover five-minute and stage boundaries, fractional minutes, cap sharing, midnight splitting, pauses and breaks, grace, replay/roundtrips, background restoration, historical migration, identity preservation and exam harvest boundaries. Existing frontend workflows also passed.

## Stage boundary

No Home, timer-screen or session-summary redesign was implemented. The cap message is returned by the model; displaying it belongs to stage 2. The achievements section and new garden rendering belong to stage 3. Full Arabic/RTL and dark mode remain stages 4 and 5. No cloud service, package dependency, Git command or phone deployment was added for stage 1.
