# Plant visual and motion pass - 14 November 2026

Approved choice: flat forest B, refined with layered hills, edge trees, sparse grass and one slow butterfly. The original photo asset remains unchanged. No new dependencies, backend or features outside this visual pass were added.

## Changed files

- New lib/motion.dart: shared durations, reduced motion, press/route effects and visible/foreground-only loops.
- New lib/forest_scene.dart: cached scenery and a separately painted 26-pixel butterfly.
- New lib/app_header.dart: shared Home/Study/Schedule header.
- lib/plant_visual.dart: one painter for five stages, intermediate growth, separate topic flowers, thumbnails and celebration.
- lib/app_theme.dart, study_ui.dart: named theme/layout values, contrast and shared controls.
- lib/home_view.dart, main.dart, study_garden.dart: main plant, other-subject thumbnails, minute-labelled stage preview; subject exam/reminder menu.
- lib/schedule_view.dart, calendar_screen.dart, focus_screen.dart, session_completion.dart: header/navigation/motion presentation only.
- test/plant_visual_motion_test.dart plus existing UI test expectations and accessibility test configuration; integration_test/visual_profile_test.dart and test_driver/visual_profile_driver.dart.
- README.md, Frontend-Status.md and the academic report generator/report.

## Verification

Flutter Analyze: no issues. Flutter Test: all 90 tests passed. Tests include five-stage painter reuse, reduced motion, background/hidden/scroll pause, disposal, aligned headers, IoT 1/1 consistency, empty-topic status and day/night/focus/stage renders. The prior IoT mismatch was not reproduced; both screens now demonstrably read the same completed-topic count. No historical cause is asserted.

Protected-file SHA-256 checks confirm that growth rules/ledger, focus timer/records, storage/data services, calendar notifications/services, original photo and dependency manifests are unchanged (13 files).

An isolated com.example.istudy.verification profile build used an in-memory mature-plant fixture on Moto G75, with real animation enabled. Each view had a 3-second warmup and 12-second sample:

| View | Frames | FPS | Build p95 | Raster p95 | Raster frames >16.67 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Home | 712 | 59.3 | 0.971 ms | 12.778 ms | 0 |
| Focus | 717 | 59.7 | 1.878 ms | 14.950 ms | 16 |

Home's initial full-scene butterfly repaint measured 47.4 FPS / raster p95 17.191 ms. Restricting its repaint region improved the subsequent short sample above. Device load varies; this is not a sustained-performance or universal 60 FPS claim. Two intervening attempts were interrupted when the phone switched away from the app; only the completed run is reported. No screen recording ran during measurement.

The main com.example.istudy debug APK was verified, installed and launched. Workspace bytes were unchanged across installation; post-launch subjects/topics matched and historical focus IDs remained. No Android/Flutter runtime errors were observed. Actual before/after screenshots: output/previews/Visual-Device-Before.png and Visual-Device-After.png. Other Growza-Visual-After-* files are controlled widget renders, not screenshots of user data.

## Limits and next work

No Rive/Lottie, cloud, new storage fields, altered growth rewards or timer behavior. The original launcher mark remains consistent with the plant style. Lock/reopen timer behavior was not re-measured on hardware in this visual pass; existing timer tests still pass. Apple hardware was not tested. Smart recommendations, quality multipliers and later blueprint phases remain separate work.
