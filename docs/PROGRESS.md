# PromptList Progress Log

Cross-loop handoff notes. Newest entries at the top.

---

## 2026-09-12 --- TASK-010 complete (Milestone 1 started)

**Done:** Added the real schema v1 in `lib/core/database/tables.dart`:
`Lists`, `Sections`, `ListItems`, matching `ARCHITECTURE.md`'s core
data model. Notes on two intentional naming deviations from the doc's
plain-English field names, both purely internal to the generated code:

- The `Lists` table uses `@DataClassName('ListRecord')` so Drift's
  auto-derived singular row class is `ListRecord`, not `List` --- which
  would otherwise collide with `dart:core`'s `List`.
- `ListItems`' text field is the column `content`, not `text`, because
  `text()` is already `Table`'s column-builder method; a getter named
  `text` cannot coexist with the inherited `text()` method Dart
  requires to define it. Domain-level code introduced in later tasks
  can still call this "item text" in its own API.

`Sections.listId` and `ListItems.sectionId` are foreign keys with
`onDelete: KeyAction.cascade`; `AppDatabase.migration.beforeOpen` turns
on `PRAGMA foreign_keys = ON` so SQLite actually enforces it (off by
default per-connection). `schemaVersion` stays `1` --- this is the
first real schema, so there is nothing to migrate from yet; future
schema changes must bump it and extend `migration` per
`ARCHITECTURE.md`.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (11/11 passing). `test/core/database/app_database_test.dart`
covers: schema version, creating/reading a list, a section under a
list, an item under a section (completion defaults false, sort order
and timestamps stored correctly), and that deleting a list cascades to
its sections and items.

**Next:** TASK-011 --- list repository CRUD.

---

## 2026-09-12 --- TASK-003 complete (Milestone 0 finished)

**Done:** Added `RootShell` (`lib/app/root_shell.dart`): a Material 3
`NavigationBar` shell switching between Lists, Templates, and AI
Create via an `IndexedStack` (preserves each tab's widget state).
Settings is intentionally not a nav destination --- it is reached via a
gear icon in the app bar and pushed as a normal route, keeping the
primary three-tab workflow uncluttered per `PRODUCT_SPEC.md` section 4.
Added placeholder screens under
`lib/features/{lists,templates,ai_generation,settings}/presentation/`
to be filled in by their respective later tasks. `PromptListApp` now
hosts `RootShell` instead of a static placeholder.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (7/7 passing, covering initial destination, switching to each
tab, selection persisting across a rebuild, and opening/closing
Settings from the app bar). No Android/iOS emulator is available in
this dev environment, so the shell was verified via the widget test
suite rather than a manual on-device run; Windows/Chrome desktop
targets were not added since only Android/iOS are in scope per
`ARCHITECTURE.md`/ADR-001.

**Milestone 0 --- Repository Foundation is now complete.**

**Next:** Milestone 1 --- Local List Foundation, starting with
TASK-010 (database schema v1).

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
