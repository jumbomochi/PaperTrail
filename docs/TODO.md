# Repo TODO — handoff 2026-06-10

Context: just merged the **Notes & Reviews** feature (28 commits on main, ending at `0b922cd`). Spec: `docs/specs/2026-05-27-notes-reviews-design.md`. Plan: `docs/superpowers/plans/2026-05-27-notes-reviews.md`.

## Notes & Reviews — open follow-ups

- [ ] **Manual smoke test on a real device.** Was attempted on the iOS simulator (booted iPhone 17 Pro), but programmatic taps weren't available (no `idb`/`cliclick`, AppleScript accessibility denied). The data path and backup format are verified end-to-end (see commit `88e1e50` tests + `/tmp/papertrail-smoke/export-v2.json` from the last run if still present). What still needs eyes-on:
  - Book detail screen renders ReviewSection + QuotesList sections
  - Long-press a quote → Copy / Share / Delete bottom sheet works (iOS share sheet with `sharePositionOrigin`)
  - Book list shows ★ / 📑N indicators on cards that have reviews/quotes
  - Search bar debounces at 200ms; results render `…matched…` snippet with `— review` / `— quote, p.N` label
  - Settings → Export Library produces a v2 JSON file; Settings → Import Library restores from it
- [ ] **Settings screen `quotes` count.** `BackupService.getCounts(...)` now returns a `.quotes` field but the import-preview UI on `lib/features/settings/screens/settings_screen.dart` doesn't display it. Add a row.
- [ ] **Delete dead `bookSearchProvider`** in `lib/features/books/providers/book_providers.dart` (the legacy server-side search provider that predates this feature — `book_list_screen.dart` does client-side filtering now and never used it).

## Pre-existing tech debt (predates this branch — fix when convenient)

- [ ] **Failing tests on main**: 3 in `test/widget/empty_state_test.dart`, 1 in `test/widget/widget_test.dart`. They predate the notes-reviews work; haven't been investigated.
- [ ] **No sqflite test harness.** Migration / repository tests would need `sqflite_common_ffi` as a dev dep. The current project verifies migrations manually via smoke testing. Adding the harness would let us catch DB schema regressions in CI.
- [ ] **`flutter analyze` info-level lints** in `book_list_screen.dart` and `book_providers.dart` — anonymous `_, __` callback params, one unused local var. Harmless but noisy.

## Bigger picture

- The pre-existing project goal is **Apple App Store submission**. Last readiness assessment (2026-03-23) was ~65-70%. Already done: Sentry crash reporting, iOS privacy manifest, photo-library usage descriptions, custom app icon + category icons, import/export. Remaining is whatever the team's App Store Connect checklist surfaces — App Store Connect listing, screenshots, TestFlight build, real-device QA pass.

## Useful pointers

- Bundle ID: `com.huiliang.paperTrail` (note: capital T — see `ios/Runner.xcodeproj/project.pbxproj`).
- Logged crashes funnel through `lib/core/services/logger_service.dart` → Sentry.
- The repo's previous solo-dev pattern was working directly on `main`; the notes-reviews feature was the first to use a feature branch (`feat/notes-reviews`, since deleted).
