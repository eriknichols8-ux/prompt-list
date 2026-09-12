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

## Development Setup: Real AI Generation

The app works fully offline without any setup: without an API key it
falls back to a deterministic built-in generator, so manual lists,
templates, and AI Create's UI all work out of the box.

To generate lists with a real OpenAI model during local development:

1.  Copy `.env.example` to `.env` and put your own OpenAI API key in
    it. `.env` is gitignored --- never commit it.
2.  Run (or build) with the key compiled in via Flutter's built-in
    `--dart-define-from-file` flag:

    ``` text
    flutter run --dart-define-from-file=.env
    ```

3.  In Android Studio, add `--dart-define-from-file=.env` to the
    `main.dart` run configuration's "Additional run args" field so the
    IDE's Run button picks it up too.

See `docs/ARCHITECTURE.md`'s "AI Provider Security" section and
`lib/main.dart` for how the key is loaded --- it is never hard-coded,
logged, or bundled as a default in a distributable build.

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
