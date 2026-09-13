# CLAUDE.md

## Mission

Build **PromptList**, a polished local-first Flutter checklist app.
Users create lists manually, from templates, or by asking AI for a list.
AI-generated or AI-modified content is always validated and previewed
before explicit acceptance.

This repository is also an autonomous-development experiment. A single
human kickoff should take the project from specification → complete
tested MVP → autonomous product/design evolution.

## Required Reading

At the start of every Ralph iteration read:

1.  `CLAUDE.md`
2.  `docs/PLAN.md`
3.  `docs/PROGRESS.md`
4.  Relevant sections of `PRODUCT_SPEC.md`, `ARCHITECTURE.md`,
    `TESTING.md`, `AI_CONTRACT.md`, and `DECISIONS.md`.

Repository state, not prior-context memory, is the source of truth.

## Current Development Mode

The functional MVP is complete.

Unless explicitly told otherwise, current Ralph runs are DESIGN EVOLUTION runs.

For design Ralph runs, read and follow:

`docs/DESIGN_RALPH.md`

Preserve working functionality. Prioritize visual identity, usability, interaction quality, cohesion, and polish.

Do not resume the original MVP backlog simply because it exists in PLAN.md.


## MVP Gate Requirements

Do not enter evolution until:

-   manual lists work;
-   item CRUD, completion, and ordering persist;
-   sections work;
-   templates work;
-   AI generation works through validation → preview → acceptance;
-   AI modification works through preview → acceptance;
-   local functionality remains useful offline;
-   formatting, analysis, and automated tests pass;
-   required integration tests pass;
-   supported builds compile where the environment permits;
-   no secrets are committed;
-   documentation reflects implementation;
-   working tree is clean;
-   all completed work is pushed.

## Git Is Part of Done

After **every completed task**:

``` text
verify → document → git status/diff → commit → push → verify remote
```

Suggested messages:

``` text
TASK-014: implement list item CRUD
EVOLVE-003: add contextual list covers
```

Do not begin the next task until the current task's commit is pushed.

At the end of every Ralph iteration, all intended work must also be
committed and pushed. If iteration-level state changed after the last
task commit, create and push a non-empty checkpoint such as:

``` text
RALPH: checkpoint iteration 07
```

Never create empty commits. Never force-push unless the human explicitly
authorizes it.

If push fails and cannot be safely restored, document the blocker and
stop rather than accumulating unpushed autonomous work.

## Testing Is Mandatory

For every task:

-   add/update appropriate tests;
-   use focused tests during implementation;
-   run formatter;
-   run analyzer;
-   run the full applicable test suite before completion.

Baseline:

``` bash
dart format .
flutter analyze
flutter test
```

Run integration/build checks when required by `TESTING.md` or the active
task.

Never delete, skip, or weaken a valid test merely to get green. Never
use a live AI service as the deterministic pass/fail oracle. Bug fixes
should receive regression tests when practical.

## Product Guardrails

-   Core checklist behavior is local-first.
-   AI is optional enhancement, not a dependency for ordinary list use.
-   AI output is untrusted.
-   New AI content follows:
    `prompt → service → structured output → validation → preview → explicit acceptance → persistence`.
-   AI-modified lists remain unchanged until explicit acceptance.
-   Once accepted, AI content behaves like normal list content.
-   Never commit or embed a privileged production AI key in a
    distributable mobile binary.

## Architecture Baseline

Unless an ADR deliberately changes it:

-   Flutter / Dart
-   Riverpod
-   Drift + SQLite
-   Material 3 foundations where useful
-   provider-independent AI service
-   deterministic fake AI service for tests
-   Android + iOS targets

Prefer simple, testable architecture over abstraction for abstraction's
sake.

# Visual Design Direction

## Design Mission

**PromptList must not look like a generic AI-generated Flutter app.**

The target is:

-   classy;
-   professional;
-   distinctive;
-   tactile;
-   modern without trend-chasing;
-   warm enough to feel personal;
-   visually memorable without becoming childish;
-   calm enough for everyday productivity.

Ralph has substantial visual-design authority. Make coherent decisions
instead of waiting for the human to choose every color, surface,
illustration, or interaction.

## Avoid Generic Generated-App Aesthetics

Avoid defaulting to:

-   Material blue or stereotypical AI purple;
-   plain white/gray backgrounds;
-   endless identical `Card` widgets;
-   every component having the same 12--16px radius;
-   generic gradient headers;
-   sparkle icons as the entire AI identity;
-   chatbot-style AI UI;
-   excessive glassmorphism;
-   random neon gradients;
-   dashboard clutter;
-   default Material buttons without intentional styling.

The application should feel **designed**, not scaffolded.

## Establish a Coherent Design System

Early in development, define and maintain:

-   primary/secondary palette;
-   neutral/background palette;
-   light and dark surface strategy;
-   typography hierarchy;
-   spacing rhythm;
-   corner geometry;
-   borders/dividers;
-   elevation/shadow approach;
-   icon treatment;
-   button families;
-   checkbox/completion treatment;
-   motion principles;
-   illustration/list-cover treatment.

Document significant choices. Do not independently redesign each screen.

## Color

Choose a restrained but memorable palette.

-   Do not default to blue or purple.
-   Use neutrals intentionally.
-   One or two distinctive accents are encouraged.
-   Backgrounds may use subtle tonal variation, pattern, texture,
    illustration, or depth.
-   State colors must remain accessible.
-   Dark mode should feel deliberately designed, not mechanically
    inverted.

Ralph owns the palette decision.

## Buttons and Controls

Create recognizable PromptList controls while preserving usability.

Tastefully explore:

-   selective/asymmetric corner geometry;
-   filled and outlined control families;
-   tactile pressed states;
-   icon containers;
-   restrained action pills;
-   a distinctive add-item control;
-   custom drag handles;
-   a memorable AI-create control;
-   custom checkbox/completion animation.

Novelty must not harm discoverability.

## Backgrounds and Surfaces

Do not assume every screen needs a flat solid background.

Consider restrained:

-   abstract artwork;
-   paper/list-inspired texture;
-   quiet patterns;
-   tonal panels;
-   generated decorative elements;
-   illustrated empty states;
-   list cover art;
-   subtle gradients.

Maintain readability and performance.

## AI-Generated Visual Assets

AI-generated imagery is explicitly encouraged when it creates identity.

Useful applications include:

-   onboarding;
-   empty states;
-   template-category art;
-   abstract list covers;
-   decorative backgrounds;
-   subtle textures;
-   AI-generation experience art.

Rules:

-   keep one coherent art direction;
-   imagery supports the product rather than dominating it;
-   optimize assets for mobile;
-   core UX must not depend on decorative imagery;
-   do not use copyrighted characters/logos/celebrity likenesses just
    because sample list content mentions them;
-   respect licensing;
-   do not commit unauthorized font/assets.

If image-generation tooling is available, Ralph may use it. If
unavailable, do not block the MVP: document the intended asset/prompt
and use a tasteful fallback.

## Typography

Use deliberate hierarchy rather than default demo typography.

Avoid excessive weights and oversized marketing headings on utility
screens.

If adding fonts, verify licensing, fallback, and app-size impact.

## Motion

Use brief purposeful motion for:

-   completion;
-   reorder;
-   creation;
-   AI preview → saved-list transition;
-   undo/recovery.

Respect reduced-motion/accessibility settings. Avoid animation merely to
signal "AI."

## AI UX

AI should feel integrated into list-making, not bolted on as a chatbot.

Prefer concepts such as:

-   "Describe the list you need"
-   "Make me a list"
-   "Change this list"

The AI-create experience should be one of the app's most distinctive
surfaces.

# Autonomous Evolution

## Authority

After MVP completion Ralph may invent features that were never
requested.

Good improvements should increase one or more of:

-   user value;
-   distinctiveness;
-   simplicity;
-   delight;
-   accessibility;
-   reliability;
-   AI usefulness;
-   organization/discovery;
-   privacy;
-   offline usefulness;
-   visual identity.

Ralph is encouraged to surprise the human.

Do not simply implement examples from documentation. Inspect the
finished product and generate new ideas.

## Selection

Before implementing an autonomous idea, evaluate:

1.  user value;
2.  fit with PromptList;
3.  distinctiveness;
4.  implementation risk;
5.  complexity/bloat;
6.  testability;
7.  visual/interaction value.

Prefer high-value, high-fit, testable ideas.

For each chosen idea:

1.  create `EVOLVE-###` in `PLAN.md`;
2.  define acceptance criteria;
3.  implement;
4.  test;
5.  verify;
6.  document;
7.  commit;
8.  push;
9.  continue.

## Evolution Guardrails

Do not autonomously:

-   add paid services or meaningful recurring costs;
-   publish to an app store;
-   purchase domains;
-   create external accounts;
-   change repository visibility;
-   expose user data;
-   add invasive analytics or advertising;
-   add authentication/cloud infrastructure without compelling
    documented reason;
-   introduce unclear-license dependencies/assets;
-   delete major working features;
-   rewrite Git history.

If an excellent idea requires one of these, document it as a future
proposal instead.

## Autonomous Design Review

During evolution repeatedly inspect:

-   Does this still resemble a generated Flutter demo?
-   Which screen has the weakest identity?
-   Are components coherent?
-   Is there a memorable interaction?
-   Is AI integrated elegantly?
-   Are empty states useful and beautiful?
-   Can a default component become more intentional without harming
    usability?
-   Does the app remain professional and accessible?

Visual improvements are valid evolution tasks.

## Refactoring

Refactor when required for active work or when tests protect a
meaningful maintainability improvement. Do not spend evolution
iterations endlessly rewriting already-clean architecture. Prefer
user-visible value.

## Blockers

A blocker is genuinely unsafe/unavailable, not merely difficult.

Examples:

-   required credentials unavailable;
-   remote push authorization unavailable;
-   required platform hardware/environment unavailable;
-   serious irreversible product decision;
-   external setup requiring human authorization.

When blocked: preserve working state, verify what can be verified,
document the exact blocker, commit/push safe completed work if possible,
and stop rather than guessing.

## Final Standard

Every fresh context must be able to understand and continue the project
from repository state alone.

The experiment succeeds when one kickoff produces:

**specification → complete tested MVP → autonomous evolution → polished,
surprising application**
