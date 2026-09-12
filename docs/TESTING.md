# PromptList Testing Strategy

## Objective

Ralph loops need an objective signal for "done." Automated tests are
part of the product contract, not cleanup after implementation.

## Test Pyramid

### Unit tests

Use for:

-   validation;
-   ordering logic;
-   progress calculations;
-   domain/application logic;
-   AI response decoding/validation;
-   repository behavior where dependencies can be isolated;
-   error mapping.

These should be fast and deterministic.

### Database tests

Use an isolated/in-memory or temporary Drift database to verify:

-   CRUD;
-   relationships;
-   cascades/constraints;
-   ordering persistence;
-   transactions;
-   template independence;
-   AI preview acceptance;
-   migrations.

Never depend on the developer's real app database.

### Widget tests

Use for important UI behavior:

-   navigation;
-   empty states;
-   create list;
-   add/edit/check item;
-   validation messages;
-   template flows;
-   AI prompt/loading/error/preview flows;
-   destructive-action UX;
-   representative accessibility semantics.

Override repositories/services with fakes when practical.

### Integration tests

Reserve for critical cross-layer journeys and release confidence.

Required by release milestone:

1.  Manual list → add/reorder/complete → restart/reload → state
    preserved.
2.  Template → instantiate → edit list → template unchanged.
3.  Fake AI → prompt → preview → accept → saved normal list.
4.  Fake AI → prompt → preview → cancel → no saved data.

## Ralph Test Sequence

For each task:

1.  Run focused tests while implementing.
2.  Run formatter.
3.  Run static analysis.
4.  Run the full unit/widget test suite before completion.

Expected final commands:

``` bash
dart format .
flutter analyze
flutter test
```

If integration tests exist and the task touches a critical flow, run the
relevant integration test as well.

## Test Rules

-   Tests must be deterministic.
-   No unit/widget test may require internet access.
-   No automated test may require a real AI API key.
-   Do not use arbitrary sleeps when a deterministic pump/wait is
    possible.
-   Do not make assertions weaker simply to make a test pass.
-   Do not delete a failing valid regression test.
-   Prefer behavior assertions over implementation-detail assertions.
-   A bug fix should add a regression test when practical.

## AI Fixtures

Maintain fixtures for at least:

### Valid

-   one unnamed section;
-   multiple named sections;
-   optional description omitted;
-   Unicode text;
-   maximum allowed practical payload boundaries.

### Invalid

-   invalid JSON;
-   missing title;
-   blank title;
-   missing sections;
-   empty sections when disallowed by the current contract;
-   blank item text;
-   wrong data types;
-   excessive item count;
-   excessive text length;
-   unexpected provider wrapper/error;
-   truncated JSON.

Tests should verify typed failures and that invalid output is never
persisted.

## Reordering Tests

At minimum test:

-   move first → last;
-   move last → first;
-   move middle → middle;
-   repeated reorder;
-   reorder after deletion;
-   reorder with one item;
-   persistence after repository reload;
-   normalization when sort gaps are exhausted, if that strategy is
    used.

## Transaction Tests

For atomic operations, force a failure partway through when practical
and verify that no partial state remains.

Critical atomic flows:

-   AI preview acceptance;
-   template instantiation;
-   AI modification apply.

## Migration Tests

When schema version increases:

-   create a representative database at the previous version;
-   populate realistic rows;
-   run migration;
-   assert rows and relationships survive;
-   assert new fields/defaults are correct.

No schema-changing task is complete without appropriate migration
coverage.

## Widget Test Quality

Widget tests should verify user-visible outcomes, not only that widgets
exist.

Prefer:

-   enter text;
-   tap action;
-   observe resulting state;
-   reload provider/screen when persistence matters;
-   verify validation/error messages.

## Accessibility Checks

Where practical:

-   semantic labels for icon-only controls;
-   meaningful checkbox semantics;
-   text scale stress on core screens;
-   no reliance on color alone for completion/error state;
-   accessible alternative for reordering if drag-only interaction is
    insufficient.

## Manual Checks

Manual testing supplements automated testing; it does not replace it.

Before release, manually inspect:

-   Android small/large phone layouts;
-   light and dark mode;
-   long list titles;
-   long item text;
-   large AI-generated lists within limits;
-   offline AI failure;
-   interrupted/retried generation;
-   drag behavior;
-   keyboard behavior in list editing.

## Failure Policy

A failing existing test means the Ralph task is not done unless:

-   the test is provably invalid because an approved requirement
    changed, and
-   the requirement/documentation is updated, and
-   the test is replaced with correct coverage.

Record unusual decisions in `PROGRESS.md` or `DECISIONS.md` as
appropriate.
