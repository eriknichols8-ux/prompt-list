# Architecture and Product Decisions

Use this file for decisions that future Ralph loops should not casually
reverse.

Keep entries concise. Add a new ADR section when a meaningful decision
is made.

------------------------------------------------------------------------

## ADR-001 --- Flutter for mobile client

**Status:** Accepted

**Decision:** Build the initial mobile app in Flutter with Android and
iOS targets.

**Reason:** One codebase, strong mobile UI support, and appropriate fit
for the intended development workflow.

------------------------------------------------------------------------

## ADR-002 --- Local-first persistence

**Status:** Accepted

**Decision:** Core checklist and template functionality is local-first
using SQLite via Drift.

**Reason:** Checking/editing lists should remain fast and usable without
internet. AI availability must not determine whether the checklist app
works.

------------------------------------------------------------------------

## ADR-003 --- Riverpod for state management

**Status:** Accepted

**Decision:** Use Riverpod for application state/dependency injection.

**Reason:** Testability and explicit dependency overrides are valuable
for autonomous development loops.

------------------------------------------------------------------------

## ADR-004 --- AI is behind a provider-independent service

**Status:** Accepted

**Decision:** UI/domain code depends on a list-generation abstraction,
not directly on a specific AI SDK.

**Reason:** Enables deterministic fakes, provider replacement, and safer
testing.

------------------------------------------------------------------------

## ADR-005 --- AI output requires preview and explicit acceptance

**Status:** Accepted

**Decision:** Generated or AI-modified list content is temporary until
the user explicitly accepts it.

**Reason:** AI output can be wrong or malformed. The user must remain in
control of persisted data.

------------------------------------------------------------------------

## ADR-006 --- Sections exist in the data model early

**Status:** Accepted

**Decision:** Model list sections from the initial database design even
though simple-list UI is implemented first.

**Reason:** AI-generated and template lists benefit from structure;
adding ownership later would create avoidable migration complexity.

------------------------------------------------------------------------

## ADR-007 --- No privileged production AI key in mobile binary

**Status:** Accepted

**Decision:** A distributable production build will not embed a
privileged provider API key.

**Reason:** Mobile binaries cannot securely protect such a secret.
Production AI access needs an appropriate secure architecture.

------------------------------------------------------------------------

## ADR-008 --- Placeholder application ID

**Status:** Accepted

**Decision:** The bootstrapped app uses org `com.promptlist.app`, giving
Android application ID `com.promptlist.app.promptlist` and a matching
iOS bundle identifier. This is a placeholder for local development and
is not a finalized store identity.

**Reason:** TASK-001 only requires the app to run on both platforms with
a documented naming placeholder. Final bundle/application IDs should be
chosen deliberately before any store submission (out of scope for the
autonomous MVP/evolution work; store publishing is an explicit
guardrail).

------------------------------------------------------------------------

## ADR Template

### ADR-### --- Title

**Status:** Proposed \| Accepted \| Superseded

**Decision:** What was decided.

**Reason:** Why.

**Consequences:** Optional important tradeoffs.

**Supersedes:** Optional ADR reference.
