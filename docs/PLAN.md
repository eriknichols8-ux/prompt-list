# PromptList Implementation Plan

## How to Use This Plan

This is the execution backlog for Ralph loops.

Rules:

-   Work on one task at a time
-   Complete one milestone at a time
-   Complete tasks in dependency order.
-   A task is not complete until its acceptance criteria and the project
    Definition of Done pass.
-   Mark a task `[x]` only after verification.
-   If blocked, leave it `[ ]` and record the blocker in `PROGRESS.md`.
-   Test fully at the end of the milestone
-   Update progress.md at the end of each milestone
-   Do not silently expand a task.

## Milestone 0 --- Repository Foundation

### [x] TASK-001 --- Bootstrap Flutter project

**Goal:** Create the application shell.

**Acceptance criteria:** - Flutter app runs. - Android and iOS targets
exist. - App has a clear package/bundle naming placeholder documented
for later finalization. - Material 3 is enabled. - `flutter analyze`
passes. - `flutter test` passes.

**Dependencies:** none.

### [x] TASK-002 --- Establish project structure and dependencies

**Goal:** Add the minimal architecture needed for the MVP.

**Acceptance criteria:** - Riverpod is configured. - Drift/SQLite is
configured. - Feature/core folders follow `ARCHITECTURE.md` or an ADR
documents an intentional variation. - No unused speculative dependencies
are added. - A smoke test still passes.

**Dependencies:** TASK-001.

### [x] TASK-003 --- App navigation and shell

**Goal:** Create primary navigation.

**Acceptance criteria:** - User can navigate among Lists, Templates, and
AI Create. - Settings is reachable without cluttering the main
workflow. - Navigation state behaves predictably. - Widget tests cover
primary navigation.

**Dependencies:** TASK-002.

## Milestone 1 --- Local List Foundation

### [ ] TASK-010 --- Database schema v1

**Goal:** Persist lists, sections, and list items.

**Acceptance criteria:** - Schema supports List, Section, and
ListItem. - Stable IDs are used. - Items have completion and sort-order
fields. - Lists/items include required timestamps. - Database tests
verify create/read behavior. - Schema versioning is established.

**Dependencies:** TASK-002.

### [ ] TASK-011 --- List repository CRUD

**Goal:** Provide testable list persistence APIs.

**Acceptance criteria:** - Create, read, rename/update, and delete list
operations exist. - Repository is independent of presentation code. -
Errors are surfaced intentionally. - Repository tests pass.

**Dependencies:** TASK-010.

### [ ] TASK-012 --- Lists home screen

**Goal:** Display saved lists.

**Acceptance criteria:** - Empty state is useful. - Saved lists are
displayed. - Each list shows title and useful completion progress. -
Tapping a list opens it. - UI updates after list changes. - Widget tests
cover empty and populated states.

**Dependencies:** TASK-011, TASK-003.

### [ ] TASK-013 --- Create blank list

**Goal:** Allow manual list creation.

**Acceptance criteria:** - User can create a list with a title. -
Blank/whitespace-only titles are rejected. - New list persists after
restart. - User lands in the new list or can immediately open it. -
Tests cover validation and persistence.

**Dependencies:** TASK-011, TASK-012.

### [ ] TASK-014 --- List item CRUD

**Goal:** Make a list useful as a checklist.

**Acceptance criteria:** - Add item. - Edit item. - Delete item. - Empty
item text is rejected. - Changes persist. - Tests cover CRUD and
validation.

**Dependencies:** TASK-013.

### [ ] TASK-015 --- Complete and uncomplete items

**Goal:** Track checklist completion.

**Acceptance criteria:** - Item can be checked and unchecked. -
Completion persists across reload/restart. - Progress on the list screen
updates. - Completed styling remains accessible/readable. - Tests cover
state transitions.

**Dependencies:** TASK-014.

### [ ] TASK-016 --- Drag-and-drop item ordering

**Goal:** Allow persistent manual ordering.

**Acceptance criteria:** - Items can be reordered by drag and drop. -
New order persists. - Repeated moves do not corrupt ordering. - Edge
cases for first/last item are tested. - Database remains the persisted
source of truth.

**Dependencies:** TASK-014.

### [ ] TASK-017 --- List management polish

**Goal:** Add essential list-level operations.

**Acceptance criteria:** - Rename list. - Delete list with appropriate
confirmation/undo behavior. - Clear completed items with safe UX. -
Empty list state is useful. - Tests cover destructive actions.

**Dependencies:** TASK-015, TASK-016.

## Milestone 2 --- Sections

### [ ] TASK-020 --- Section domain/repository operations

**Goal:** Fully support sections already represented in schema.

**Acceptance criteria:** - Create, rename, delete, and reorder
sections. - Items belong to a section. - Moving items between sections
is supported at the domain/repository layer. - Data integrity is tested.

**Dependencies:** TASK-017.

### [ ] TASK-021 --- Section UI

**Goal:** Expose sections in the list editor.

**Acceptance criteria:** - Sections render clearly. - User can
add/rename/delete/reorder sections. - User can move/reorder items
appropriately. - A simple list can still feel simple; sections are not
forced on the user. - Widget tests cover primary interactions.

**Dependencies:** TASK-020.

## Milestone 3 --- Templates

### [ ] TASK-030 --- Template schema and repository

**Goal:** Persist reusable templates.

**Acceptance criteria:** - Template data is separate from active list
completion state. - Templates support sections and ordered items. -
Repository CRUD is tested. - Schema migration is tested if schema
version changes.

**Dependencies:** TASK-021.

### [ ] TASK-031 --- Built-in templates

**Goal:** Ship a small useful starter set.

**Acceptance criteria:** - At least 5 useful built-in templates exist. -
Built-ins are deterministic and do not require AI/network access. -
Built-ins are distinguishable from user templates if needed for editing
rules. - Tests verify template loading.

**Dependencies:** TASK-030.

### [ ] TASK-032 --- Create list from template

**Goal:** Instantiate independent lists.

**Acceptance criteria:** - User previews/selects a template and creates
a list. - New list contains copied structure/items. - Completion begins
unchecked. - Editing the new list does not mutate the source template. -
Tests verify independence.

**Dependencies:** TASK-031.

### [ ] TASK-033 --- Save list as user template

**Goal:** Turn an existing list into a reusable template.

**Acceptance criteria:** - User can save a list as a template. -
Completion state is not carried into future lists. - Template name can
be edited. - Tests cover list → template → new list flow.

**Dependencies:** TASK-032.

### [ ] TASK-034 --- Template management UI

**Goal:** Browse and manage templates.

**Acceptance criteria:** - Built-in and user templates are easy to
browse. - User templates can be renamed/deleted. - Destructive actions
are safe. - Widget tests cover template management.

**Dependencies:** TASK-033.

## Milestone 4 --- AI Generation Foundation

### [ ] TASK-040 --- AI domain contract

**Goal:** Define provider-independent generation models/interfaces.

**Acceptance criteria:** - `ListGenerationService` or equivalent
abstraction exists. - Generated list DTO/domain model is separate from
persisted list entities. - Contract supports generation and future
modification. - Fake/mock implementation exists for tests. - No live
provider dependency leaks into UI/domain tests.

**Dependencies:** TASK-002.

### [ ] TASK-041 --- AI structured response validator

**Goal:** Safely convert model output into a preview model.

**Acceptance criteria:** - Implements `AI_CONTRACT.md`. - Rejects
malformed JSON/structure. - Enforces documented size/text limits. -
Handles optional descriptions/section titles. - Produces useful typed
failures. - Comprehensive deterministic tests cover valid and invalid
payloads.

**Dependencies:** TASK-040.

### [ ] TASK-042 --- AI prompt screen

**Goal:** Capture the user's request.

**Acceptance criteria:** - User can enter a prompt. - Empty prompts are
rejected. - Loading state prevents accidental duplicate submissions. -
Cancel/back behavior is safe. - Uses fake AI service in widget tests.

**Dependencies:** TASK-040, TASK-003.

### [ ] TASK-043 --- Generated list preview

**Goal:** Never persist AI output without review.

**Acceptance criteria:** - Generated title, sections, and items are
shown before saving. - User can remove unwanted generated items. - User
can edit the list title before saving. - Cancel discards generated
data. - No database records are created before acceptance. - Tests
explicitly verify the no-persist-before-accept rule.

**Dependencies:** TASK-041, TASK-042.

### [ ] TASK-044 --- Accept AI list into local database

**Goal:** Convert approved preview into a normal checklist.

**Acceptance criteria:** - Accepting preview creates list/sections/items
atomically. - Generated list behaves identically to a manual list
afterward. - AI source metadata, if stored, does not create separate
behavior. - Failure does not leave a partial list. - Integration-style
tests cover the transaction.

**Dependencies:** TASK-043, TASK-011.

### [ ] TASK-045 --- Development AI provider adapter

**Goal:** Connect one real model provider for development.

**Acceptance criteria:** - Provider is isolated behind the AI service
interface. - Secrets are not hard-coded or committed. - Development
configuration is documented. - Timeouts, malformed responses, provider
errors, and retryable failures map to app-level failures. - Automated
tests use mocks/fixtures rather than live calls.

**Dependencies:** TASK-041.

### [ ] TASK-046 --- AI generation UX/error handling

**Goal:** Make generation resilient.

**Acceptance criteria:** - User sees understandable failure states. -
Retry is available where appropriate. - Existing lists/data are never
affected by a generation failure. - Duplicate submissions are
prevented. - Loading and failure widget tests pass.

**Dependencies:** TASK-044, TASK-045.

## Milestone 5 --- AI List Editing

### [ ] TASK-050 --- AI modification contract

**Goal:** Support natural-language changes to an existing list.

**Acceptance criteria:** - Existing list snapshot + instruction can be
sent through provider-independent interface. - Result uses the same
validated generated-list contract. - Original persisted list is
unchanged until user accepts. - Tests cover contract and validation.

**Dependencies:** TASK-046.

### [ ] TASK-051 --- "Ask AI to change this list" UI

**Goal:** Let users issue modification instructions.

**Acceptance criteria:** - Existing list offers an AI modify action. -
User can enter instructions such as "alphabetize this" or "add the TV
shows." - Proposed result opens in preview. - Cancel preserves original
list exactly. - Widget tests use fake AI.

**Dependencies:** TASK-050.

### [ ] TASK-052 --- Apply approved AI modification

**Goal:** Safely replace/update list content after approval.

**Acceptance criteria:** - User explicitly approves changes. - Update is
atomic. - Completion-state behavior is defined and tested. - Failed
apply leaves original list intact. - Tests cover success and
rollback/failure.

**Dependencies:** TASK-051.

## Milestone 6 --- UX and Reliability

### [ ] TASK-060 --- Search and basic organization

**Goal:** Make lists easier to find as data grows.

**Acceptance criteria:** - User can search list titles/items as defined
in product spec. - Search is responsive for normal local data volumes. -
Tests cover matching and no-result states.

**Dependencies:** TASK-017.

### [ ] TASK-061 --- Undo for common destructive actions

**Goal:** Reduce accidental data loss.

**Acceptance criteria:** - Appropriate delete/clear actions support undo
or confirmation according to UX choice. - Undo restores correct
order/state. - Tests cover undo.

**Dependencies:** TASK-017.

### [ ] TASK-062 --- Accessibility and interaction polish

**Goal:** Ensure core workflows are usable.

**Acceptance criteria:** - Controls have useful semantics/labels. -
Touch targets are reasonable. - Text scaling does not break core
screens. - Completed items are not communicated by color alone. -
Drag/reorder has an accessible alternative if needed. - Relevant tests
pass.

**Dependencies:** TASK-034, TASK-046.

### [ ] TASK-063 --- Dark mode/theme behavior

**Goal:** Support system theme cleanly.

**Acceptance criteria:** - Light/dark follow system by default. - Core
screens remain readable in both. - No hard-coded colors break
contrast. - Widget tests cover representative theme rendering.

**Dependencies:** TASK-003.

## Milestone 7 --- Release Readiness

### [ ] TASK-070 --- Critical integration flows

**Goal:** Protect the product's highest-value journeys.

**Acceptance criteria:** - Automated integration coverage exists for: -
create manual list → add/reorder/complete → reload; - template → create
list → edit independently; - AI fake generation → preview → accept →
edit as normal list; - AI fake generation → cancel → verify nothing
persisted. - Tests are deterministic.

**Dependencies:** TASK-062.

### [ ] TASK-071 --- Data migration safety

**Goal:** Verify schema upgrades preserve user data.

**Acceptance criteria:** - Migration tests cover every schema version
introduced so far. - Representative old database fixtures upgrade
without data loss. - No production code resets the DB as a migration
shortcut.

**Dependencies:** all schema-changing tasks.

### [ ] TASK-072 --- Production AI secret architecture

**Goal:** Make the AI path safe for a distributable app.

**Acceptance criteria:** - Production architecture does not ship a
privileged provider key in the app. - Secure proxy/backend approach is
documented and implemented if store distribution is planned. -
Abuse/rate-limit/error considerations are documented. - Local
development remains straightforward.

**Dependencies:** TASK-045.

### [ ] TASK-073 --- Release verification

**Goal:** Produce a release candidate.

**Acceptance criteria:** - `dart format .` passes. - `flutter analyze`
passes. - `flutter test` passes. - Integration suite passes. - Android
release build compiles. - iOS build is verified in an appropriate macOS
environment before iOS release. - No secrets or debug-only credentials
are present. - Product spec reflects shipped behavior.

**Dependencies:** TASK-070, TASK-071, TASK-072.

## Post-MVP Parking Lot

Do not implement these unless they are promoted into numbered tasks:

-   Cloud sync
-   Accounts/login
-   Collaboration/shared lists
-   Reminders/notifications
-   Sharing/export
-   Template variables
-   Home-screen widgets
-   Voice input
-   Image/photo → list
-   Store subscriptions
-   Cross-device sync
-   Web app
-   AI suggestions that run automatically without explicit user action
