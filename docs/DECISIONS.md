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

## ADR-009 --- Production AI access via a server-side proxy (documented, not implemented)

**Status:** Accepted as the target architecture; implementation
deliberately deferred.

**Decision:** Before this app is ever distributed outside local
development, AI generation/modification requests must go through a
small, authenticated, rate-limited server-side proxy that holds the
real provider API key --- never a client-embedded one. Concrete design
for when that work is authorized:

-   **Transport:** client sends `{ prompt }` or `{ snapshot,
    instruction }` to the proxy over HTTPS, exactly like today's direct
    call to the provider, plus a lightweight app-issued auth token (not
    the end user's own credential, and never the provider's own key).
-   **Proxy responsibilities:** hold the real provider key as a
    server-side secret; authenticate the request; enforce per-device/
    per-IP rate limits to bound cost and abuse; re-enforce
    `AI_CONTRACT.md`'s size limits server-side too (defense in depth,
    since a modified client could send oversized payloads); forward
    the same canonical system+user content to the provider; return the
    provider's response (or a normalized error) unchanged.
-   **Client-side validation is unaffected:** the proxy does not
    duplicate `GeneratedListValidator`'s structural validation --- that
    stays the single source of truth on the client, exactly as it is
    today. The proxy only owns transport/auth/rate-limiting/cost
    control.
-   **Client change required:** because `ListGenerationService` is
    already provider-independent (ADR-004), swapping the direct
    OpenAI call for a proxied one is a contained, isolated change --- a
    new implementation behind the same interface, pointed at the
    proxy's URL with the proxy's own lightweight token instead of
    `OpenAiListGenerationService`'s API key. No domain or UI code
    changes.
-   **Error mapping needs no new categories:** a proxy rate-limit
    response maps to the existing `AiGenerationFailureType.rateLimited`;
    a proxy auth failure maps to `providerError`; proxy
    unavailability maps to `network`/`timeout` --- the same typed
    failures already implemented in TASK-045/046 cover this without
    modification.
-   **Logging:** request metadata (timestamp, device token, status,
    token usage) may be logged for abuse monitoring; full prompts/list
    content must not be, per `ARCHITECTURE.md`'s Logging section.

**Reason:** ADR-007 already forbids embedding a privileged key in a
distributable binary; this ADR specifies *how* production access
actually works once store distribution is pursued, so a future loop
has a concrete design instead of a vague pointer.

**Consequences:** Implementing this requires provisioning and paying
for real server hosting (and likely a domain/account), which
CLAUDE.md's Evolution Guardrails explicitly forbid doing
autonomously ("do not add paid services or meaningful recurring
costs", "do not create external accounts"). This ADR is therefore a
**documented, deferred** plan: none of the server-side pieces above
are implemented by this task, and must not be autonomously implemented
later either without explicit human authorization to provision real
infrastructure. Local development is unaffected: the existing `.env` +
`--dart-define-from-file` mechanism (TASK-045) remains the correct,
explicitly-documented development-only path (see
`ARCHITECTURE.md`'s "AI Provider Security" section) until store
distribution is actually authorized.

**Supersedes:** none; elaborates on ADR-007's "needs an appropriate
secure architecture" with a concrete design.

------------------------------------------------------------------------

## ADR-010 --- Android-only release target for now

**Status:** Accepted

**Decision:** iOS build verification (TASK-073's macOS/Xcode
requirement) is not required for this project to be considered
release-ready. The user has confirmed there is no current plan to
release on iOS. Android remains the actively verified release target;
`flutter build apk --release` and the full test suite are the release
gate.

**Reason:** TASK-073's own acceptance criterion is scoped to "before
iOS release," not "before every release." With no iOS release planned,
that criterion doesn't apply yet rather than being permanently
unmet. This was a genuine environment blocker (no macOS available in
this session) until the user clarified iOS isn't a current goal at
all, which resolves it outright instead of merely deferring it.

**Consequences:** The codebase keeps its iOS platform folder and
target (ADR-001 is not reversed --- nothing here removes iOS support
from the project), so iOS remains buildable later without rework.
Future Ralph loops should not block release readiness on an iOS build
check unless the user asks for iOS release again, at which point
TASK-073's iOS criterion becomes active again and needs an actual
macOS/Xcode environment to verify.

**Supersedes:** none; narrows TASK-073's scope rather than reversing
any prior ADR.

------------------------------------------------------------------------

## ADR Template

### ADR-### --- Title

**Status:** Proposed \| Accepted \| Superseded

**Decision:** What was decided.

**Reason:** Why.

**Consequences:** Optional important tradeoffs.

**Supersedes:** Optional ADR reference.
