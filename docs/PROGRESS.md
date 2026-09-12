# PromptList Progress Log

Cross-loop handoff notes. Newest entries at the top.

---

## 2026-09-12 --- TASK-017 complete (Milestone 1 finished)

**Done:** `ListDetailScreen` now has a `PopupMenuButton` (explicit
`Icons.more_vert`, not the platform-adaptive default, so it renders
identically everywhere and is easy to find in tests) with three
actions:

- **Rename** --- `RenameListDialog` (same shape as `CreateListDialog`/
  `EditItemDialog`: pre-filled, Save disabled while blank) calling the
  existing `ListRepository.renameList`.
- **Clear completed** --- confirmation dialog (`showConfirmDialog`, new
  shared helper at `lib/core/ui/confirm_dialog.dart`) then
  `ListItemRepository.clearCompleted`.
- **Delete list** --- confirmation dialog, then *soft*-deletes via a
  new `ListRepository.archiveList` (stamps `archivedAt`, matching the
  schema field `ARCHITECTURE.md` already reserved for this), pops back
  to the Lists screen, and shows a SnackBar with an Undo action calling
  the new `unarchiveList`. Existing `deleteList` (hard delete) is
  untouched and still used/tested from TASK-011. `_EmptyItemsState`
  (empty-list body) got an icon to match the Lists screen's empty
  state; the literal empty-state text is unchanged so existing tests
  still pass.

**Two real bugs found and fixed while testing this, both worth
remembering:**

1. The delete/undo SnackBar's `onPressed` originally called
   `ref.read(listRepositoryProvider)` from inside the callback ---  but
   by the time the user taps "Undo", `ListDetailScreen` has already
   been popped and disposed, and using its `ref` after that throws.
   Fixed by reading the repository *once*, before popping, and
   capturing that instance in the closure instead of `ref` itself.
   General lesson: never capture `ref` in a callback meant to run after
   the widget that owns it is expected to be gone --- capture the value
   you need from it instead.
2. `listByIdProvider` (from TASK-013) was a `FutureProvider.family` ---
   a one-shot fetch. Renaming a list never updated the app bar title,
   because nothing re-ran that fetch. Added
   `ListRepository.watchList(id)` (a `Stream<ListRecord?>`, `null` if
   the list doesn't exist) and switched `listByIdProvider` to
   `StreamProvider.family` over it. Same category of gap as TASK-015's
   `watchListSummaries` fix: a provider that only fetches once will
   silently go stale the moment something adds a way to mutate the
   data it depends on.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (62/62 passing). New repository tests: `archiveList`/
`unarchiveList` (hides/restores without touching sections or items,
and `watchLists` reactivity), `watchList` (reactive to rename), and
`clearCompleted` (removes only completed items, no-op when none are).
New widget tests: renaming via the menu updates the app bar, clearing
completed after confirmation, and the full delete → confirm → pop →
undo flow (this last one is what caught bug #1 above --- it hung for
several minutes before failing, because the thrown exception inside
the gesture handler left the test's gesture arena in a bad state; a
quick `flutter analyze`/logic read wouldn't have caught it, only
actually driving the interaction did).

**Milestone 1 --- Local List Foundation is now complete**: manual lists
support full create/read/rename/delete (with undo), item add/edit/
delete/complete/reorder, and list-level management, all backed by
Drift/SQLite and covered by 62 automated tests.

**Next:** Milestone 2 --- Sections, starting with TASK-020 (section
domain/repository operations).

---

## 2026-09-12 --- TASK-016 complete

**Done:** Added `ListItemRepository.reorderItem({listId, oldIndex,
newIndex})`: fetches the list's current item order, does a plain
`List.removeAt`/`insert`, then --- in one transaction --- rewrites
*every* item's `sortOrder` to a fresh spaced sequence
(1000, 2000, ...). This sidesteps `ARCHITECTURE.md`'s "normalize when
gaps are exhausted" fallback entirely: since every reorder
renormalizes the whole list, gaps can never shrink to begin with. This
is deliberately the "alternative strategy...simpler and well tested"
the doc allows, appropriate given typical list sizes stay small.
Index semantics are final-list-position (post-removal), matching
Flutter's `ReorderableListView.onReorderItem` (not the deprecated
`onReorder`, which reports a pre-removal index the caller must
adjust).

`ListDetailScreen`'s item list is now a `ReorderableListView.builder`
with default drag handles disabled in favor of an explicit trailing
`Icons.drag_handle` (via `ReorderableDragStartListener`) placed after
the delete button, keeping the checkbox/text/delete row layout
unchanged from TASK-014/015.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (51/51 passing). New `reorderItem` repository tests cover every
case `TESTING.md` calls out: move first→last, last→first,
middle→middle, repeated reorders (asserts final order *and* that
resulting sort-order values stay strictly increasing with no
duplicates), reordering after a deletion, a single-item list
(no-op), and that the new order survives a fresh repository instance
reading the same database. Added one widget test driving an actual
drag gesture on the handle; a plain `tester.drag()` (no intermediate
pumps) never triggered the reorder, so it uses
`tester.startGesture`/`moveBy`/pump/`up` instead --- worth remembering
for any future `ReorderableListView` test.

**Next:** TASK-017 --- list management polish (rename, delete with
confirmation/undo, clear completed, empty-list state).

---

## 2026-09-12 --- TASK-015 complete

**Done:** Added `ListItemRepository.setItemCompleted` (sets `completed`
and stamps/clears `completedAt` together --- application code owns
completion state, never the raw `completed` flag alone, per
`AI_CONTRACT.md`'s later-relevant principle that persisted state is
never set implicitly). `ListDetailScreen` items now have a leading
`Checkbox` bound to that; completed items get a line-through and
`onSurfaceVariant` color on their text (state is carried by the
checkbox itself, not color alone).

**A real reactivity gap found and fixed while testing "progress on the
list screen updates":** `ListRepository.watchListSummaries()` (from
TASK-012) was built as `watchLists().asyncMap(...)` doing a separate
count query per list. Since `watchLists()` only watches the `lists`
table, it never re-emitted when an item's `completed` flag changed
elsewhere --- the Lists screen's progress bars would have silently gone
stale the moment TASK-015 shipped completion toggling. Rewrote it as a
single query joining `lists` --- `sections` --- `listItems` (left outer,
so lists with zero items/sections still appear) with `groupBy` and
`count(filter: ...)` aggregates; Drift's table-dependency tracking on
`.watch()` now re-emits on changes to any of the three tables. Worth
remembering generally: an `asyncMap` over one table's stream, doing
further queries against other tables inside the map, will not react to
changes in those other tables --- the reactive query has to actually
reference every table whose changes should trigger a re-emit.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (43/43 passing). Added a `watchListSummaries` repository test
that toggles an item's `completed` column directly (bypassing the
repository) and confirms the stream re-emits with the new count ---
this is what would have caught the gap above. Added a `ListsScreen`
widget test doing the same at the UI layer (progress text updates from
"0/2" to "1/2" after the underlying row changes) and a
`ListDetailScreen` test covering check/uncheck toggling the checkbox
and the strikethrough styling in both directions.

**Next:** TASK-016 --- drag-and-drop item ordering.

---

## 2026-09-12 --- TASK-014 complete

**Done:** Added `ListItemRepository`/`DriftListItemRepository`
(`lib/features/lists/domain/list_item_repository.dart`,
`lib/features/lists/data/drift_list_item_repository.dart`):
`watchItems`, `addItem`, `editItemText`, `deleteItem`. Items are
addressed by `listId` even though they belong to sections in the
schema, since sections aren't user-facing until Milestone 2 ---
`addItem` resolves the list's (currently single, default) section
internally and assigns the next spaced sort-order value
(`ARCHITECTURE.md`'s 1000/2000/... scheme). Both `addItem` and
`editItemText` reject blank text via `ListItemValidationException`,
mirroring `ListRepository`.

Built out `ListDetailScreen` (was a title-only placeholder since
TASK-012): a persistent bottom "add item" field (Add button disabled
for blank/whitespace input), a `ListView` of items each opening
`EditItemDialog` (new,
`lib/features/lists/presentation/edit_item_dialog.dart` --- pre-filled
text, Save disabled for blank, shared shape with `CreateListDialog`)
on tap, and a trailing delete icon per item. No checkbox yet ---
completion is TASK-015 --- and no confirmation on delete yet ---
destructive-action UX is TASK-017.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (38/38 passing). New
`test/features/lists/data/drift_list_item_repository_test.dart` covers
add (trimmed text, increasing sort order, blank rejected/persists
nothing), edit (updates text, blank rejected/leaves item unchanged),
delete, and `watchItems` emitting on each change. New
`test/features/lists/presentation/list_detail_screen_test.dart` covers
the empty state, adding an item (shown, input cleared), the add button
disabled for blank input, editing, and deleting.

**Next:** TASK-015 --- complete and uncomplete items.

---

## 2026-09-12 --- TASK-013 complete

**Done:** Added a "New list" FAB to `ListsScreen` (now returns its own
nested `Scaffold` so it owns that FAB independently of the other
tabs) that opens `CreateListDialog`
(`lib/features/lists/presentation/create_list_dialog.dart`). The
dialog's Create button is disabled while the trimmed title is empty
(so blank/whitespace-only titles can't be submitted from the UI at
all) and calls `ListRepository.createList` --- which already rejects a
blank title itself, from TASK-011 --- on submit; on success it pops
with the created `ListRecord`. `ListsScreen` then pushes
`ListDetailScreen` for that new list, satisfying "user lands in the
new list."

New-list persistence after restart relies on the same drift_flutter
file-backed `AppDatabase` connection and repository behavior already
covered by TASK-010/011's tests (a fresh query reads back what an
earlier one wrote); there is no separate "restart" test here since
that guarantee isn't specific to this task.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (27/27 passing). New
`test/features/lists/presentation/create_list_dialog_test.dart` covers
Create being disabled for blank/whitespace input and enabled once
non-blank text is entered, cancelling persisting nothing, and
submitting creating exactly one row with the trimmed title. Extended
`lists_screen_test.dart` with an end-to-end case: tap the FAB, enter a
title, tap Create, land on `ListDetailScreen`, navigate back, and see
the new list with "No items yet."

**Next:** TASK-014 --- list item CRUD.

---

## 2026-09-12 --- TASK-012 complete

**Done:** Built the real `ListsScreen`
(`lib/features/lists/presentation/lists_screen.dart`) replacing the
placeholder: a useful empty state (explains the three creation paths
per `PRODUCT_SPEC.md` section 14, without implying buttons that don't
exist until TASK-013) and, when lists exist, cards showing title, a
linear progress bar, and an "N/M completed" label, tapping through to
`ListDetailScreen` (new placeholder,
`lib/features/lists/presentation/list_detail_screen.dart`, filled in
starting TASK-013/014). Progress needs item counts, so added
`ListSummary` (domain value object) and `watchListSummaries()` to
`ListRepository`/`DriftListRepository` (a join over `sections`/
`listItems` grouped by list, counting total and completed items per
list); existing `watchLists()` is unchanged and still used/tested.
Added Riverpod providers (`lib/features/lists/presentation/
list_providers.dart`): `listRepositoryProvider`, `listSummariesProvider`
(`StreamProvider`), `listByIdProvider` (`FutureProvider.family`).

**Two real bugs found and fixed while wiring this up, both worth
remembering for future widget tests that touch Riverpod + Drift:**

1. `appDatabaseProvider.overrideWithValue(...)` (used by every widget
   test to inject an in-memory database) bypasses the provider's own
   `ref.onDispose(database.close)`, since `overrideWithValue` never
   runs the original provider body. `test/support/test_providers.dart`
   now requires the caller to create the `AppDatabase` explicitly and
   close it in `tearDown`.
2. Independent of that: cancelling a Drift `.watch()` stream (which
   happens when Riverpod disposes a `StreamProvider`) schedules an
   internal zero-duration debounce `Timer`. flutter_test's default
   widget-tree teardown between tests doesn't give that timer a chance
   to fire before its "no pending timers" check runs, and the failure
   gets attributed to whichever test happens to be running next
   (mirrors the cosmetic reporter mislabeling noted after TASK-002 ---
   both are timing/attribution artifacts of tests sharing an isolate).
   Fixed by a new `driftTestWidgets` helper (same file) that, after the
   test body, unmounts the tree and calls
   `tester.pump(const Duration(milliseconds: 1))` --- a plain `pump()`
   with no duration does **not** elapse the fake clock at all, so it
   would not have flushed the timer; a nonzero duration is required.
   All widget tests exercising a Drift-backed screen should use
   `driftTestWidgets` instead of `testWidgets`.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (23/23 passing). New
`test/features/lists/presentation/lists_screen_test.dart` covers the
empty state, a populated state with correct per-list progress text,
and tapping a list to open `ListDetailScreen`.

**Next:** TASK-013 --- create blank list.

---

## 2026-09-12 --- TASK-011 complete

**Done:** Added `ListRepository` (domain interface,
`lib/features/lists/domain/list_repository.dart`) and
`DriftListRepository` (implementation,
`lib/features/lists/data/drift_list_repository.dart`) with
`watchLists`, `getList`, `createList`, `renameList`, and `deleteList`.
`createList` validates a non-blank title (throwing
`ListValidationException` otherwise, nothing persisted), trims
title/description, and --- inside a transaction --- creates the list
together with one default section (per the "Default Section Strategy"
in `ARCHITECTURE.md`) so items can be attached immediately in later
tasks. IDs are generated via an injectable `String Function()`
(defaulting to `Uuid().v4`) so tests can use deterministic IDs.
`deleteList` relies on the cascade FK from TASK-010. `watchLists`
excludes archived lists and is reactive via Drift's `.watch()`.

Added `uuid` as a direct dependency (was previously only transitive).

**Bug found and fixed during this task:** the `renameList` test
initially failed an `updatedAt` freshness assertion --- Drift's default
`DateTimeColumn` storage is unix-timestamp integers (second
resolution), so two writes within the same second produced identical
`updatedAt` values. Added `build.yaml` setting
`store_date_time_values_as_text: true` for `drift_dev`, which makes
Drift store/compare `DateTime` columns as ISO-8601 text with full
precision; regenerated `app_database.g.dart`. This is a project-wide
setting (confirmed via the generated `DriftDatabaseOptions`), so it
applies uniformly to the real app connection and to in-memory test
connections alike --- worth remembering before writing any future test
that compares timestamps.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (20/20 passing). New
`test/features/lists/data/drift_list_repository_test.dart` covers
title/description trimming, blank-title rejection on create and
rename (nothing persisted/changed), get-by-id (found and missing),
rename updating `updatedAt`, delete cascading to sections/items, and
`watchLists` emitting on create and excluding archived lists.

**Next:** TASK-012 --- Lists home screen.

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
