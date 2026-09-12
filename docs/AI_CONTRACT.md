# AI List Contract

## Purpose

AI output is untrusted external data.

This document defines the structured contract between an AI provider
adapter and PromptList's generated-list preview.

Provider-specific response wrappers may differ. The adapter must
produce/validate the canonical structure before application use.

## Canonical Generated List

``` json
{
  "title": "Marvel Movies in Chronological Order",
  "description": "A checklist of movies ordered by in-universe chronology.",
  "sections": [
    {
      "title": null,
      "items": [
        { "text": "Captain America: The First Avenger" },
        { "text": "Captain Marvel" },
        { "text": "Iron Man" }
      ]
    }
  ]
}
```

## Required Fields

### Root

-   `title`: string, required
-   `description`: string or null, optional
-   `sections`: array, required

### Section

-   `title`: string or null
-   `items`: array, required

### Item

-   `text`: string, required

The AI must not provide persisted IDs, completion state, database
timestamps, or sort-order values. The app owns those.

## Validation

Initial recommended limits:

-   Prompt: 1--2,000 characters after trimming
-   Title: 1--120 characters after trimming
-   Description: 0--1,000 characters
-   Sections: 1--50
-   Section title: 0--120 characters
-   Total items: 1--500
-   Item text: 1--500 characters

These are product safeguards, not model-token limits.

If requirements later need larger lists, update this contract and tests
deliberately.

## Normalization

The validator may:

-   trim leading/trailing whitespace;
-   convert absent optional description to null;
-   convert an empty/whitespace section title to null.

The validator should **not** silently:

-   invent missing item text;
-   merge semantically different items;
-   remove content because it "looks wrong";
-   repair arbitrary malformed JSON with guesses.

## Invalid Response

Return a typed failure when:

-   payload is not parseable;
-   required fields are absent;
-   types are wrong;
-   title is blank;
-   sections are missing/empty;
-   item text is blank;
-   limits are exceeded.

The UI should offer a useful retry path.

Invalid output must never be persisted.

## Generation Prompt Requirements

Provider adapters should instruct the model to:

-   return only the requested structured format when supported;
-   generate a useful concise title;
-   organize into sections only when helpful;
-   avoid adding completion state;
-   preserve requested ordering;
-   not include commentary outside the schema.

If the provider supports native structured outputs/schema enforcement,
prefer it.

## Factual Lists

Some prompts request facts that may be ambiguous or time-sensitive, for
example:

-   "all Marvel movies";
-   "current presidents";
-   "2026 Oscar winners."

The model may be wrong or incomplete.

The preview is therefore mandatory. The app should not claim generated
factual lists are authoritative.

Future versions may add grounded/web-backed generation, but that is
outside the initial MVP unless explicitly planned.

## Modification Contract

Modification input contains:

-   a normalized snapshot of the existing list;
-   the user's modification instruction.

Modification output uses the same canonical Generated List structure.

Example instruction:

``` text
Include the Disney+ shows and keep everything in chronological order.
```

The result remains preview-only until accepted.

## Completion State During Modification

AI does not decide persisted completion state.

When applying a modification, application code determines whether
existing completion can safely be preserved.

Preferred rule:

-   preserve completion for confidently matched unchanged existing
    items;
-   new/changed ambiguous items default to incomplete;
-   never let the AI directly set completed=true.

The exact matching strategy must be defined/tested during TASK-052.

## Test Fixtures

Maintain deterministic fixtures for:

-   simple list;
-   sectioned list;
-   Unicode;
-   maximum-size boundary;
-   malformed JSON;
-   wrong types;
-   blank strings;
-   too many items;
-   overlong fields;
-   provider error wrapper.

## Security

Never include secrets in prompts.

Treat user list content as potentially private.

Production logging should not record full prompts or list contents by
default.

A production mobile binary must not contain a privileged provider API
key.
