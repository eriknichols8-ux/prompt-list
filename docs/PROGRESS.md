# PromptList Progress Log

Cross-loop handoff notes. Newest entries at the top.

---

## 2026-09-12 --- TASK-043 complete

**Done:** Added `GeneratedListPreviewScreen`
(`lib/features/ai_generation/presentation/generated_list_preview_screen.dart`),
the mandatory review step between AI generation and a real list. It
takes an in-memory `GeneratedList` and renders an editable title
field plus every section/item; each item has a remove button
(`Icons.remove_circle_outline`, tooltip "Remove") that deletes it from
local widget state only. The bottom bar's "Add to my lists (N items)"
button is disabled once every item has been removed and otherwise
pops the route with a rebuilt `GeneratedList` (trimmed title, falling
back to the original if cleared blank; sections with zero remaining
items dropped). The app-bar close icon (tooltip "Cancel") pops with
`null`, discarding every edit. Critically, this widget has **no**
dependency on any repository or database provider at all --- it is
purely an in-memory editor, which is what makes "no persistence
before acceptance" true by construction rather than by convention.

`AiCreateScreen` (TASK-042) now pushes this screen immediately on a
successful generation instead of showing the old inline summary
stub, and awaits its result: `null` (cancelled) leaves the prompt
text untouched for editing/retry, while an accepted `GeneratedList`
clears the prompt and shows a "List accepted." `SnackBar`. Turning an
accepted result into real list/section/item rows is explicitly
deferred to TASK-044 and called out in a code comment at the
acceptance call site, so the next task has an obvious hook rather
than a stub to reverse-engineer.

`test/support/test_providers.dart`'s `wrapWithProviders` was
considered for an `overrides` passthrough parameter to combine a test
database with other provider overrides, but Riverpod 3.4.3 doesn't
publicly export the `Override` type (confirmed by reading the
package source: `flutter_riverpod.dart` and `riverpod.dart` both curate
their exports and omit it), so a `List<Override>` parameter can't be
named from outside the package. Documented the working alternative
instead (nest a second `ProviderScope` around the wrapped widget) and
left the helper's signature unchanged.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test --concurrency=1` (169/169 passing, up from 161). New test files:
`generated_list_preview_screen_test.dart` (shows title/sections/items;
removing an item hides it and updates the count; accept is disabled
at zero items; accepting returns the edited title with removed items
dropped and empty sections filtered out; cancelling pops `null` and
discards edits) and `ai_create_no_persist_test.dart`, which drives the
full prompt -> generate -> preview flow against a real in-memory
`AppDatabase` and asserts `lists`/`sections`/`listItems` all stay
empty after both cancelling and accepting --- the explicit
no-persist-before-accept test this task's acceptance criteria call
for. Updated `ai_create_screen_test.dart` for the new push-based flow
(preview screen assertions instead of the old inline-summary text).
Also manually exercised the full flow on the Android emulator: entered
a prompt, reviewed the generated items, removed one, edited nothing
further, and confirmed accepting returned to a cleared prompt screen
with a "List accepted." confirmation.

**Next:** TASK-044 --- accept AI list into local database (turn an
accepted `GeneratedList` into real `List`/`Section`/`ListItem` rows
atomically via the existing repositories, then behave like a normal
list from that point on).

---

## 2026-09-12 --- TASK-042 complete

**Done:** Replaced the `AiCreateScreen` placeholder with a real prompt
capture flow ("Describe the list you need" per the AI UX direction in
`CLAUDE.md`, not a chatbot-style interface). Added
`listGenerationServiceProvider`
(`lib/features/ai_generation/presentation/ai_generation_providers.dart`),
a `Provider<ListGenerationService>` defaulting to
`FakeListGenerationService` until TASK-045 wires a real adapter behind
the same interface --- widget tests override it with their own
scripted fake/controllable service, so nothing here depends on a live
provider.

`AiCreateScreen` is a `ConsumerStatefulWidget`: a multi-line `TextField`
plus a "Make me a list" `FilledButton` whose `onPressed` is null
whenever the trimmed prompt is empty or a request is already in
flight (mirrors the existing `_canSubmit` pattern from
`CreateListDialog`). Submitting increments a `_requestId` counter
before awaiting `ListGenerationService.generateList`; the response is
only applied if `mounted` and the id still matches, so a cancelled or
superseded request can never resurrect stale state. While generating,
the button is replaced by a spinner + "Cancel" (bumps `_requestId` and
resets `_isGenerating`, discarding whatever the in-flight call
eventually returns). A successful result shows a minimal inline
summary (title + item count) with "Start over"; a failed result shows
the typed `AiGenerationFailure.message` inline and leaves the prompt
editable for retry. Nothing is persisted at any point in this
screen --- reviewing/editing the generated content is the dedicated
preview flow in TASK-043, which will replace this inline summary.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test --concurrency=1` (161/161 passing, up from 153). New
`test/features/ai_generation/presentation/ai_create_screen_test.dart`
(7 tests) covers: submit disabled until non-blank text is entered,
whitespace-only rejection, successful generation showing the summary,
a typed error message on failure, the loading state blocking
duplicate submission (using a `Completer`-backed
`_ControllableGenerationService`), cancelling mid-generation
discarding a result that resolves later, and "Start over" clearing
the field. Also manually exercised the full flow on the Android
emulator (`emulator-5554`, release build): entered "Camping trip",
tapped "Make me a list", and confirmed the summary rendered "3 items
generated" with a working "Start over" button.

**Next:** TASK-043 --- generated list preview (show the generated
title/sections/items for review, allow removing items and editing the
title, and guarantee nothing is persisted before explicit acceptance).

---

## 2026-09-12 --- TASK-041 complete

**Done:** Added `GeneratedListValidator`
(`lib/features/ai_generation/domain/generated_list_validator.dart`),
implementing the response side of `AI_CONTRACT.md`. `validate(String)`
JSON-decodes a raw provider response and delegates to `validateMap`
for structural validation; both return an `AiGenerationResult` so a
rejected payload is reported as a typed
`AiGenerationFailureType.invalidResponse` rather than a thrown
exception. Enforces every documented limit as a named constant
(`titleMaxLength` 120, `descriptionMaxLength` 1000, `maxSections` 50,
`sectionTitleMaxLength` 120, `maxTotalItems` 500, `itemTextMaxLength`
500): missing/blank/wrong-typed `title`, `sections`, or item `text`
are rejected; optional `description` and section `title` trim
whitespace and normalize a blank value to `null` (per the contract's
allowed normalization); item/section/root type mismatches, empty
sections/items arrays, and any limit overrun are rejected with a
specific message. Deliberately does not attempt to repair or guess at
malformed content, matching the contract's "must not silently invent
missing text" rule.

Scoped to response validation only, not prompt validation --- prompt
entry/rejection belongs to TASK-042 (prompt screen), even though
`AI_CONTRACT.md` documents both limits together.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test --concurrency=1` (153/153 passing, up from 127). New
`test/features/ai_generation/domain/generated_list_validator_test.dart`
covers every fixture category from `AI_CONTRACT.md`'s Test Fixtures
list except the provider-error wrapper (that belongs to TASK-045's
provider adapter, which maps transport/provider errors before they
ever reach this validator): simple list, sectioned list, Unicode text,
maximum-size boundary (title/description/section-title/item-text all
at their max length, 50 sections x 10 items = 500 total items),
malformed JSON, non-object JSON root, wrong types (title, description,
sections, section, items, item text), blank title/item text, missing
required fields, too many sections, too many total items, and each
overlong-field case.

**Next:** TASK-042 --- AI prompt screen (capture the user's request,
reject empty prompts, use `FakeListGenerationService` in widget
tests).

---

## 2026-09-12 --- TASK-040 complete (Milestone 4 started)

**Done:** Added the provider-independent AI generation contract under
`lib/features/ai_generation/domain/`:

-   `GeneratedItem` / `GeneratedSection` / `GeneratedList` --- plain,
    hand-equality DTOs matching the canonical structure in
    `AI_CONTRACT.md`. Deliberately separate from the persisted `Lists`
    / `Sections` / `ListItems` Drift entities: nothing here has an id,
    completion state, or sort order, since the app only assigns those
    after explicit acceptance. The same shape is documented to be
    reused for modification proposals in TASK-050, so no second DTO
    set will be needed later.
-   `AiGenerationFailureType` / `AiGenerationFailure` --- typed failure
    categories (invalid prompt, network, timeout, rate limit, provider
    error, invalid response, unknown) so TASK-046's UX work has
    something more useful to branch on than a raw exception.
-   `AiGenerationResult` --- a sealed `AiGenerationSuccess` /
    `AiGenerationError` result type, so `ListGenerationService`
    reports expected failures as data instead of throwing.
-   `ListGenerationService` --- the abstract contract
    (`generateList(prompt)`); a future OpenAI adapter (TASK-045)
    implements it in the data layer, swapped in behind a Riverpod
    provider. Nothing outside that future adapter will depend on a
    concrete provider.
-   `FakeListGenerationService` (`lib/features/ai_generation/data/`)
    --- deterministic default implementation for tests (echoes the
    trimmed prompt into a 3-item single-section list; rejects a blank
    prompt) with an `onGenerate` override hook for scripting specific
    success/failure scenarios in later widget tests (TASK-042/043).

Did not add Riverpod provider wiring or the OpenAI dependency yet ---
those belong to TASK-042 (prompt screen) and TASK-045 (real provider
adapter) respectively; TASK-040 is domain-only per its acceptance
criteria. Confirmed the `.env` file (holding the local OpenAI key)
still exists locally and remains untouched/uncommitted; it isn't
wired into any code yet.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test --concurrency=1` (127/127 passing, up from 121). New tests:
`test/features/ai_generation/domain/generated_list_test.dart` (value
equality) and
`test/features/ai_generation/data/fake_list_generation_service_test.dart`
(deterministic default output, blank-prompt rejection, `onGenerate`
override).

**Next:** TASK-041 --- AI structured response validator (turn raw
provider JSON into a validated `GeneratedList`, enforcing the size
limits in `AI_CONTRACT.md`).

---

## 2026-09-12 --- TASK-034 complete (Milestone 3 finished)

**Done:** `TemplatesScreen` now groups templates under "Built-in" and
"My Templates" headings (each omitted when empty) instead of a flat
list with a per-card tag --- more literally "easy to browse" than a
tag buried in each card, and `watchTemplates()` already sorted
built-ins first so the partition just splits on that existing order.

`TemplateDetailScreen` gained a management menu (Rename, Delete ---
`rename_template_dialog.dart` new, blank rejected; delete confirms
first via the existing `showConfirmDialog` before calling
`deleteTemplate` and popping back with a SnackBar) shown **only** for
user templates --- built-ins render no menu at all, so
`TemplateRepository`'s existing "built-ins are immutable" guard
(TASK-030/031) stays a defensive backstop rather than something a
normal user could ever actually trigger, the same pattern already
used for "delete the only section" in TASK-021.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test --concurrency=1` (121/121 passing, up from 117). Updated
`templates_screen_test.dart`'s grouping test (now checks both
headings render, in the right vertical order, and that "My Templates"
disappears when there are no user templates) and added rename/delete
widget tests to `template_detail_screen_test.dart`, plus a check that
a built-in template shows no `more_vert` menu at all.

**Milestone 3 --- Templates is now complete**: schema/repository,
5 built-in templates, create-list-from-template, save-list-as-
template, and full template browsing/management, all covered by
automated tests.

**Next:** Milestone 4 --- AI Generation Foundation, starting with
TASK-040 (AI domain contract).

---

## 2026-09-12 --- TASK-033 complete

**Done:** Added `saveListAsTemplate` (a plain top-level function,
`lib/features/templates/domain/save_list_as_template.dart`, not a
repository method): takes `SectionRepository`+`ListItemRepository`+
`TemplateRepository` plus a `listId`/`name`/`description`, reads the
list's current sections/items, groups items by section, and calls the
existing `TemplateRepository.createTemplate` with the resulting
`TemplateSectionInput`s --- completion state is dropped simply because
nothing about `ListItemRecord.completed` is ever read into a
`TemplateSectionInput`. Kept as a standalone function rather than a
method on either repository since it's a genuine cross-feature
orchestration with no natural single owner; `createTemplate` already
had everything it needed.

Wired a "Save as template" action into `ListDetailScreen`'s menu:
`SaveAsTemplateDialog` (pre-filled with the list's current title,
blank rejected) then `saveListAsTemplate`, with a confirmation
SnackBar. "Template name can be edited" was already satisfied by
TASK-030's `renameTemplate`, usable via TASK-034's upcoming management
UI.

**A real bug found and fixed while testing this:** `saveListAsTemplate`
originally read the list's structure via
`sectionRepository.watchSections(listId).first` /
`itemRepository.watchItems(listId).first` --- reactive `.watch()`
streams, subscribed to and immediately cancelled just to grab one
value. This isn't just wasteful: it made the widget test for "Save as
template" genuinely flaky, because nothing in `ListDetailScreen`
watches those providers, so the chain's completion wasn't tied to any
frame Flutter's `pumpAndSettle()` would wait for. Fixed by adding
proper one-shot reads --- `SectionRepository.getSections` and
`ListItemRepository.getItems` --- mirroring the `getX`/`watchX` pairing
`ListRepository` and `TemplateRepository` already use, and switching
`saveListAsTemplate` to them. General lesson: a `.watch(...).first`
call is a code smell wherever a plain one-shot read would do; prefer
adding (or reusing) a real `getX` method.

**Also discovered:** `flutter test`'s default concurrency
intermittently hangs on this machine when running the full suite
(multiple widget-test isolates in parallel appear to contend for
resources) --- several full-suite runs this session stalled
indefinitely partway through with no error, only recovering when
re-run with `flutter test --concurrency=1`. That flag reliably runs
the whole suite start to finish (slower, but deterministic) and
incidentally also eliminates the cosmetic cross-file test-name
mislabeling noted since TASK-002. Recommended for this project's
verification runs on this machine going forward.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test --concurrency=1` (117/117 passing, up from 111). New
`save_list_as_template_test.dart` covers copying sections/items while
dropping completion, multiple sections, and the full acceptance-
criterion flow: list → template → new list, confirming the new list's
copy starts unchecked and that editing it afterward mutates neither
the template nor the original source list. New widget test drives the
actual "Save as template" menu action end to end.

**Next:** TASK-034 --- template management UI.

---

## 2026-09-12 --- TASK-032 complete

**Done:** Added `ListRepository.createListFromTemplate(TemplateWithSections)`:
takes an already-fetched template structure (not a template ID) so
`ListRepository` doesn't need a live dependency on `TemplateRepository`
--- just the plain read-only `TemplateWithSections` data shape. In one
transaction it creates a new list (title/description copied) plus a
fresh section per template section (fresh IDs throughout) and a fresh
item per template item, always `completed: false`. A template with no
sections still produces a normal, usable list with one default
section, matching `createList`.

Built out the real `TemplatesScreen` (replacing the TASK-003
placeholder): browses all templates, a "Built-in" tag on built-in
ones, tap through to a new `TemplateDetailScreen` --- a read-only preview
of the description/sections/items --- with a "Create list" button. That
button reads the template's current structure, calls
`createListFromTemplate`, and pushes straight into `ListDetailScreen`
for the new list (mirroring TASK-013's "land in the new list"
pattern).

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (111/111 passing, up from 106). New repository tests cover
copying title/description/sections/items, copied items always
starting unchecked, an empty template still yielding a usable
one-section list, and --- the explicit independence check the task
calls for --- editing the new list's item text/completion and renaming
the list, then confirming the source template's stored structure is
untouched. New widget tests cover the templates list (empty state,
built-in tag, tap-through) and the preview-to-created-list flow,
scoping assertions to the newly-pushed `ListDetailScreen` specifically
since the `TemplateDetailScreen` underneath (which shows the same
item text in its own preview) stays mounted in the navigation stack.

**Next:** TASK-033 --- save list as user template.

---

## 2026-09-12 --- TASK-031 complete

**Done:** Added 5 built-in templates as fixed Dart data
(`lib/features/templates/data/built_in_templates.dart`: Grocery Run,
Weekend Trip Packing, Moving Day, Weekly House Cleaning, Morning
Routine --- each with real sections and items, no network/AI call
involved, so they're deterministic by construction) and
`TemplateRepository.seedBuiltInTemplates()`: idempotent (checks for
any existing `isBuiltIn` row first, so it's safe to call on every app
startup without duplicating). Wired seeding into `main.dart` --- it now
builds a `ProviderContainer`, awaits `seedBuiltInTemplates()` before
the first frame, then hands that same container to the widget tree
via `UncontrolledProviderScope` (so seeding and the rest of the app
share one `AppDatabase` instance rather than opening two).

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (102/102 passing, up from 99): seeding produces at least 5
built-in templates whose names match the fixed set, each with its
full section/item structure intact, and calling it twice never
duplicates anything. Also manually ran the app on an Android emulator
after the `main.dart` change (an async `main()` plus the
`ProviderContainer`/`UncontrolledProviderScope` startup pattern is
worth actually launching, not just `flutter analyze`-checking) and
confirmed it still starts normally with no crash from the new seeding
step.

**Next:** TASK-032 --- create list from template.

---

## 2026-09-12 --- TASK-030 complete (Milestone 3 started)

**Done:** Added the schema for reusable templates --- `Templates`,
`TemplateSections`, `TemplateItems` (`lib/core/database/tables.dart`)
--- structurally mirroring `Lists`/`Sections`/`ListItems` but with no
`completed`/`completedAt` columns at all on `TemplateItems`, so
"template data is separate from active list completion state" is
enforced by the schema itself, not just by convention.
`Templates.isBuiltIn` (default `false`) distinguishes built-in from
user templates for TASK-031's editing rules. This is schema v2:
bumped `AppDatabase.schemaVersion` to `2` and added an `onUpgrade` step
that creates the three new tables when migrating from v1 --- purely
additive, so existing data is untouched.

**Migration test:** added a `V1Database` fixture
(`test/core/database/fixtures/v1_database.dart`, `@DriftDatabase`
over just `Lists`/`Sections`/`ListItems` at `schemaVersion 1`, reusing
the real table classes so the fixture can't drift from the real v1
schema) used only to build a v1 SQLite file on disk, populate it with
a list/section/(completed) item, close it, then reopen the same file
with the real `AppDatabase` (v2) and confirm: all v1 data survives
unchanged, and the new template tables exist and are immediately
usable. This is the pattern to reuse for every future schema bump ---
`TESTING.md` requires it and TASK-071 will require it for every
version introduced along the way.

**Repository:** Added `TemplateRepository`/`DriftTemplateRepository`
(`lib/features/templates/domain/template_repository.dart`,
`lib/features/templates/data/drift_template_repository.dart`).
Templates are built and read as a *whole structure* in one call
(`createTemplate(name, description?, isBuiltIn?, sections:
[TemplateSectionInput(title?, items: [...])])` /
`getTemplate`/`watchTemplate` returning a `TemplateWithSections` tree)
rather than through per-section/per-item CRUD --- nothing in the
product plan calls for interactively editing a template's contents
piece by piece, only creating one wholesale (built-ins in TASK-031,
"save list as template" in TASK-033) and reading one wholesale (to
instantiate a list in TASK-032), so a smaller CRUD surface here avoids
building machinery nothing will use. `renameTemplate`/`deleteTemplate`
throw `TemplateValidationException` for a built-in template --- built-
ins are immutable from the start, ahead of TASK-031 actually shipping
any.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (99/99 passing, up from 84). Also fixed a genuinely-stale
existing test (`app_database_test.dart`'s schema-version assertion,
hardcoded to `1`) to assert the real current version rather than
weakening or deleting it, per `TESTING.md`'s failure policy: the
requirement legitimately changed and is documented above.
`drift_template_repository_test.dart` covers name/description
trimming and blank-name rejection, nested section/item ordering,
`watchTemplate` reacting to a rename, `watchTemplates` ordering
(built-ins first, then alphabetical), and the built-in
rename/delete guard.

**Next:** TASK-031 --- built-in templates.

---

## 2026-09-12 --- TASK-020 and TASK-021 complete (Milestone 2 finished)

**Implemented together, in one commit:** TASK-021 (section UI) depends
on TASK-020 (section domain/repository), and one specific piece of
TASK-020 --- scoping item reordering to a single section instead of a
whole list --- required changing `ListItemRepository.reorderItem`'s
signature, which the existing (single-section) `ListDetailScreen`
already called. There was no way to land TASK-020 as a commit that
both builds and leaves the UI behaving correctly without first doing
at least the minimal section-aware UI work, so the two were done as
one integrated change rather than forcing an artificial, temporarily-
broken split.

**Domain/repository (TASK-020):** Added `SectionRepository`/
`DriftSectionRepository` (`lib/features/lists/domain/
section_repository.dart`, `lib/features/lists/data/
drift_section_repository.dart`): `watchSections`, `createSection`
(title optional, trimmed, blank → null), `renameSection` (same
normalization; unlike list/item text a section title is allowed to be
blank), `deleteSection` (cascades its items via the existing FK, but
throws `SectionValidationException` if it's the list's *only*
remaining section --- every list must always have at least one, per
`ARCHITECTURE.md`'s "Default Section Strategy"), and `reorderSection`
(same renormalize-everything-every-move strategy as
`ListItemRepository.reorderItem`).

Extended `ListItemRepository`: `addItemToSection` (explicit section
target) alongside the existing `addItem(listId)` (now resolves the
list's *first* section by sort order --- still meaningful with several
sections, and unchanged behavior for the common single-section list);
`moveItemToSection` (relocates an item, appending it after the target
section's existing items); `reorderItem` now takes `sectionId` instead
of `listId` and only reorders within that one section --- it no longer
touches other sections' items at all.

**UI (TASK-021):** `ListDetailScreen` now renders one of two views,
computed from a new `sectionsWithItemsProvider` (combines
`sectionsProvider` + `itemsProvider`, both already reactive):

- **1 section (the common case):** identical to before --- flat
  checklist, no section chrome, global bottom add-item field. This is
  the literal mechanism behind PRODUCT_SPEC.md section 8: "A basic
  list should not require the user to understand sections."
- **2+ sections:** each section renders as its own block --- a header
  (tap the title to rename; up/down/delete controls) followed by its
  own drag-reorderable item list and its own inline add-item field.
  Each item also gets a "move to section" action (a picker over the
  *other* sections) when more than one section exists.

Section reordering uses up/down icon buttons rather than drag-and-drop
--- nesting two independently-draggable `ReorderableListView`s (one for
sections, one per section for its items) is a known-fragile Flutter
pattern, and drag-and-drop was only an explicit requirement for items
(TASK-016), not sections. Item drag-and-drop within a section is
unchanged from TASK-016, just correctly scoped per section now.
"Add section" lives in the existing list-level menu
(`lib/features/lists/presentation/section_dialog.dart` for the
create/rename dialog, which --- unlike `RenameListDialog`/
`EditItemDialog` --- always allows saving blank, since an untitled
section is valid;
`lib/features/lists/presentation/move_to_section_dialog.dart` for the
move picker).

A UI consequence worth noting: once a list is back down to one
section, there is no section-delete control at all (simple mode has no
section chrome), so `deleteSection`'s "can't delete the only section"
guard is unreachable through this screen by construction --- it only
matters for direct repository callers, which is exactly what
`drift_section_repository_test.dart` exercises.

**Verified:** `dart format .`, `flutter analyze` (no issues), `flutter
test` (84/84 passing, up from 62). New
`drift_section_repository_test.dart` covers create/rename (including
blank → null)/delete (cascade, and refusing the last section)/reorder
(the same first→last/last→first/repeated/persistence battery as
TASK-016's item tests). Extended
`drift_list_item_repository_test.dart` with `addItemToSection`,
`moveItemToSection` (moved item appended after the target section's
existing items), and confirmation that `reorderItem` no longer
disturbs a different section's order. New
`list_detail_screen_sections_test.dart` covers adding a section
(header appears), renaming, deleting (and the simple-mode fallback
above), section reordering, and moving an item between sections.

**Milestone 2 --- Sections is now complete.**

**Next:** Milestone 3 --- Templates, starting with TASK-030 (template
schema and repository).

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
