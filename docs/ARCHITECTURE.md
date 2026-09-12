# PromptList Architecture

## Goals

The architecture should make Ralph loops safe and small.

It should:

-   keep UI, persistence, and AI concerns separable;
-   make most behavior testable without a device or network;
-   keep local list operations independent of AI availability;
-   permit replacing the AI provider;
-   support schema migrations without data loss;
-   avoid unnecessary enterprise complexity.

## Technology Baseline

-   Flutter / Dart
-   Riverpod
-   Drift
-   SQLite
-   Material 3

Changes to these choices require an entry in `DECISIONS.md`.

## Layers

### Presentation

Flutter widgets, screens, dialogs, view state, navigation.

Presentation code may depend on domain/application abstractions. It
should not issue SQL or parse raw provider JSON.

### Domain/Application

Use cases, entities/value objects where useful, validation,
repository/service interfaces, orchestration.

Avoid abstraction for abstraction's sake. Add a use-case class when it
clarifies behavior or makes it testable; simple repository/provider
calls can remain simple.

### Data

Drift tables/DAOs/repository implementations, provider adapters,
serialization.

Provider-specific AI code belongs here or under `core/ai`.

## Suggested Layout

``` text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    ai/
    database/
    errors/
    models/
    utils/
  features/
    lists/
      data/
      domain/
      presentation/
    templates/
      data/
      domain/
      presentation/
    ai_generation/
      data/
      domain/
      presentation/
    settings/
      presentation/
```

Do not create empty folders purely to satisfy the diagram.

## Core Data Model

### List

-   id
-   title
-   description?
-   createdAt
-   updatedAt
-   archivedAt?
-   source?

### Section

-   id
-   listId
-   title?
-   sortOrder

### ListItem

-   id
-   sectionId
-   text
-   completed
-   sortOrder
-   createdAt
-   completedAt?

### Template

Template storage may mirror list/section/item structure or use dedicated
tables. The implementation must guarantee independence between templates
and instantiated lists.

## Default Section Strategy

To keep simple lists simple, every persisted item should have a valid
section relationship. A list may automatically contain one
unnamed/default section.

The UI can hide the default section heading.

This avoids nullable ownership while allowing sections later.

## IDs

Use stable generated IDs appropriate for local-first data.

Tests must not rely on production randomness; inject/fix IDs where
determinism is useful.

## Transactions

Use a transaction for operations such as:

-   accepting an AI-generated list;
-   instantiating a template;
-   applying an approved AI modification;
-   deleting a list with dependent rows when not handled safely by
    constraints;
-   any multi-row reorder/normalization that must be atomic.

A failure must not leave half-created structures.

## Ordering

Preferred initial strategy: spaced integer ordering values, e.g.:

``` text
1000
2000
3000
```

A move can assign an intermediate value when possible.

If gaps become too small, normalize the affected collection in a
transaction.

Alternative strategies are allowed if they are simpler and well tested.

## State Management

Riverpod providers should expose application state without making
widgets responsible for persistence.

Guidelines:

-   keep provider scope narrow;
-   avoid giant global state objects;
-   repository/provider dependencies should be injectable;
-   tests should override dependencies with fakes;
-   UI should represent loading/error/data states explicitly when
    asynchronous.

## AI Boundary

Domain interface concept:

``` dart
abstract interface class ListGenerationService {
  Future<GeneratedList> generate(String prompt);

  Future<GeneratedList> modify(
    GeneratedList existing,
    String instruction,
  );
}
```

Exact Dart types may evolve, but provider-specific SDK objects must not
leak across this boundary.

### GeneratedList is not a persisted List

Generated content is temporary preview data.

Only explicit acceptance converts it into persisted entities.

## AI Provider Security

For local development, configuration is supplied through a
non-committed development mechanism: a gitignored `.env` file loaded
at build/run time via Flutter's `--dart-define-from-file` (see
`OpenAiListGenerationService` and `main.dart`, TASK-045). Without a key
configured, the app falls back to a deterministic fake service rather
than failing --- AI is optional, never a hard dependency.

For an app distributed to end users, do not embed a privileged AI
provider secret in the application binary.

Before production distribution, use a secure architecture such as a
small authenticated/rate-limited server-side proxy, or another
deliberately approved approach. See `DECISIONS.md`'s ADR-009 for the
concrete target design (transport, proxy responsibilities, required
client-side change, error mapping) --- documented and ready to
implement when store distribution is actually authorized, but not
implemented yet, since doing so requires provisioning paid hosting
that this project's autonomous-evolution guardrails do not permit
without explicit human authorization.

## AI Validation

Provider response handling should separate:

1.  transport/provider success;
2.  structured decoding;
3.  schema validation;
4.  conversion to preview model.

Never let malformed AI output crash the UI or write partial data.

See `AI_CONTRACT.md`.

## Database Migrations

Every schema change must:

1.  increment schema version;
2.  define a migration;
3.  preserve existing valid user data;
4.  include migration tests;
5.  avoid destructive reset as a convenience.

## Error Model

Prefer typed/domain failures where callers need to react differently.

Examples:

-   validation failure;
-   database failure;
-   network unavailable;
-   AI timeout;
-   AI malformed response;
-   AI provider rejection/rate limit.

Do not over-engineer a universal error hierarchy before it is needed.

## Logging

Development logging may include useful technical context.

Never log:

-   API keys/tokens;
-   authorization headers;
-   private credentials.

Avoid logging full user prompts/list contents by default in production
because lists may contain personal information.

## Performance

MVP is designed for ordinary personal list volumes. Optimize only when
evidence or obvious algorithmic issues justify it.

Basic expectations:

-   checking an item feels immediate;
-   list rendering is smooth for normal list sizes;
-   reordering does not rewrite the entire database unnecessarily on
    every drag frame;
-   database writes occur at sensible interaction boundaries.

## Architecture Change Rule

If a Ralph task discovers that this architecture materially blocks a
correct implementation:

-   do not quietly redesign the app;
-   document the proposed change in `DECISIONS.md`;
-   make the smallest justified change;
-   update this file in the same task.
