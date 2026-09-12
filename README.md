# PromptList

A local-first Flutter checklist app where lists can be created manually,
from templates, or from natural-language AI prompts.

## Signature Flow

``` text
"Generate a list of the Marvel movies"
        ↓
AI structured response
        ↓
Validated preview
        ↓
User accepts
        ↓
Normal editable checklist
```

## Ralph Development

This repository is designed for one-task-at-a-time Ralph loops.

Start here:

1.  `CLAUDE.md`
2.  `docs/PLAN.md`
3.  `docs/RALPH.md`
4.  `docs/PROGRESS.md`

Suggested invocation:

``` text
Run one Ralph development loop for this repository.

Follow CLAUDE.md exactly.
Read docs/PLAN.md and docs/PROGRESS.md.
Select the first incomplete task whose dependencies are complete.
Implement only that task.
Run all required verification.
If it passes, update PLAN.md and PROGRESS.md.
If blocked, document the blocker and leave the task incomplete.
Do not begin another task.
```

## Documentation

-   `docs/PRODUCT_SPEC.md` --- product behavior
-   `docs/ARCHITECTURE.md` --- technical boundaries
-   `docs/TESTING.md` --- verification strategy
-   `docs/AI_CONTRACT.md` --- structured AI output contract
-   `docs/DECISIONS.md` --- decisions future loops should respect
-   `docs/PROGRESS.md` --- cross-loop handoff
