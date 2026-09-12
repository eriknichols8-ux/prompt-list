# PromptList Progress Log

Cross-loop handoff notes. Newest entries at the top.

---

## 2026-09-12 --- TASK-002 complete

**Done:** Added Riverpod (`flutter_riverpod`) and Drift/SQLite
(`drift`, `drift_flutter`, transitively `sqlite3_flutter_libs`) plus
`path_provider`/`path` as runtime deps, and `drift_dev`/`build_runner`
as dev deps. Created `lib/core/database/app_database.dart`: an
`AppDatabase` with an intentionally empty table list (tables arrive in
TASK-010) so the Drift + `build_runner` codegen path and the
Riverpod-provided instance (`lib/core/database/database_provider.dart`,
`appDatabaseProvider`) are proven end-to-end ahead of the real schema.
Wrapped the app root in `ProviderScope` in `main.dart`. Generated
`.g.dart` files are excluded from `flutter analyze` via
`analysis_options.yaml` (standard practice for Drift-generated code).
No new `features/` folders were created yet --- nothing lives in them
until the tasks that need them (avoids empty scaffold folders per
`ARCHITECTURE.md`).

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (2/2 passing: the existing app smoke test plus a new
`test/core/database/app_database_test.dart` that opens/queries an
in-memory `AppDatabase`). Confirmed native `sqlite3` works in this dev
environment for in-memory Drift tests without extra setup. Note: the
`flutter test` compact/expanded reporter occasionally mislabels which
test file a progress line belongs to when multiple suites run
concurrently on this machine --- cosmetic only; the final pass count is
correct and authoritative.

**Next:** TASK-003 --- app navigation and shell (Lists, Templates, AI
Create, Settings).

---

## 2026-09-12 --- TASK-001 complete

**Done:** Bootstrapped the Flutter app with `flutter create --org
com.promptlist.app --project-name promptlist --platforms android,ios
--empty .`. Replaced the generated placeholder with `lib/app/app.dart`
(`PromptListApp`, Material 3 enabled via `ColorScheme.fromSeed`,
placeholder terracotta seed color to avoid default Material
blue/purple) and a smoke widget test at `test/app_test.dart`. Set
`pubspec.yaml` description. Android and iOS platform folders exist.
Application ID naming placeholder is documented in ADR-008
(`com.promptlist.app.promptlist` / matching iOS bundle id) --- not
finalized for store distribution.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (1/1 passing).

**Repo/Git:** Initialized git repo, added `.gitignore` (excludes
`.env`, which holds a local OpenAI API key, plus Flutter/Android/iOS
build artifacts). Created new public GitHub repo
`eriknichols8-ux/prompt-list` (the previous `promptlist` repo under the
same account contains unrelated old code and was intentionally not
reused). Pushed initial docs commit and TASK-001 commit to `main`.

**Next:** TASK-002 --- establish project structure and dependencies
(Riverpod, Drift/SQLite, feature/core folders per `ARCHITECTURE.md`).
