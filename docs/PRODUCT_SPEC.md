# PromptList Product Specification

## 1. Product Summary

PromptList is a fast, local-first checklist app with three creation
paths:

1.  Blank list
2.  Reusable template
3.  Natural-language AI prompt

The signature experience is:

> Tell the app what list you need, review what AI generated, then turn
> it into a normal checklist.

## 2. Product Principles

### Lists first, AI second

AI helps create or transform lists. It does not create a separate class
of content.

### Local-first

Normal list use must work without an internet connection. AI generation
may require a connection.

### User remains in control

AI output is previewed before persistence. AI must not silently rewrite
an existing list.

### Fast by default

Opening a list, checking an item, adding an item, and reordering items
should not depend on network access.

### Simple surface, capable model

Sections and structured data can exist without making basic checklists
feel complicated.

## 3. Core User Stories

### Manual lists

As a user, I can create a blank list so I can track anything I want.

As a user, I can add, edit, delete, reorder, complete, and uncomplete
items.

As a user, I can rename or delete a list.

### Templates

As a user, I can create a new list from a reusable template.

As a user, I can save one of my lists as a template.

### AI generation

As a user, I can type a request such as:

-   "Generate a list of the Marvel movies in chronological order."
-   "Packing list for four days in Breckenridge in September."
-   "Checklist for publishing an Android app."
-   "Grocery list for tacos for six people."

The app generates a structured preview.

I can review the result before it becomes a saved list.

### AI modification

As a user, I can ask AI to modify an existing list, for example:

-   "Alphabetize this."
-   "Include the TV shows too."
-   "Remove duplicates."
-   "Split this grocery list by aisle."
-   "Add anything important I forgot."

The original list remains unchanged until I approve the proposed result.

## 4. Primary Navigation

### Lists

Default landing area. Shows saved lists and progress.

### Templates

Shows built-in and user-created templates.

### AI Create

Fast path to prompt-based generation.

### Settings

Secondary destination for app preferences and AI configuration/status.
Currently a lightweight placeholder screen; showing whether a real AI
provider is configured (vs. the offline fallback) is a natural
follow-up, not yet implemented.

## 5. List Behavior

A list has:

-   stable ID
-   title
-   optional description
-   zero or more sections
-   zero or more items
-   created timestamp
-   updated timestamp
-   optional archived/deleted state as implemented
-   optional source metadata

A list title must contain non-whitespace text.

## 6. Item Behavior

An item has:

-   stable ID
-   text
-   completion state
-   sort order
-   created timestamp
-   optional completion timestamp
-   section relationship

Item text must contain non-whitespace text.

Checking/unchecking an item must persist immediately enough that normal
app termination does not unexpectedly lose the action.

## 7. Ordering

Users can reorder items with drag and drop.

Ordering must persist across navigation and app restart.

Sections, when exposed, can also be reordered (via explicit up/down
controls, not drag).

Item reordering also exposes "move up"/"move down" as accessibility
actions (available whenever applicable, i.e. not at either end of the
list), so reordering does not require performing a drag gesture.

## 8. Sections

Sections organize groups of items.

A basic list should not require the user to understand sections. The app
may use a default unnamed section internally.

Example:

``` text
Packing

Clothing
[ ] Shirts
[ ] Pants

Electronics
[ ] Charger
[ ] Power bank
```

## 9. Templates

A template contains reusable structure, not active completion state.

Creating a list from a template:

-   copies the template's title/description/sections/items as
    appropriate;
-   creates new IDs;
-   creates unchecked items;
-   creates an independent list.

Editing a resulting list must not mutate its template.

Saving an existing list as a template does not preserve completion state
for future instances.

## 10. AI Generation Flow

``` text
User prompt
    ↓
Generation request
    ↓
Structured model response
    ↓
Validation
    ↓
Preview
    ↓
User edits/removes content if desired
    ↓
Explicit Create List action
    ↓
Atomic persistence
    ↓
Normal checklist
```

No list records are persisted before explicit acceptance.

## 11. AI Preview

At minimum, preview allows:

-   viewing generated title;
-   viewing sections/items;
-   editing the title;
-   removing unwanted items;
-   canceling;
-   accepting/creating the list.

Regenerate/edit-prompt functionality may be added when scheduled.

## 12. AI Modification Flow

``` text
Existing list snapshot + user instruction
    ↓
AI response
    ↓
Validation
    ↓
Proposed-list preview
    ↓
Cancel OR Accept
    ↓
Atomic update if accepted
```

The original list is preserved until acceptance.

Completion-state mapping during AI modifications, as implemented: an
item in the proposed result keeps its existing completion only when
its trimmed text exactly matches an existing item's trimmed text (each
existing item can satisfy at most one match, so duplicate text never
double-preserves); a reworded, new, or extra duplicate item always
starts unchecked. The AI is never able to set completion directly ---
its output format has no completion field at all.

## 13. Offline Behavior

Without internet:

-   create/edit/delete local lists;
-   add/reorder/complete items;
-   use local templates;
-   browse existing data.

AI actions should fail gracefully with a clear message that connectivity
is required.

## 14. Empty States

### No lists

Explain the three creation paths and emphasize AI without making it
mandatory.

### Empty list

Provide a direct add-item action.

### No user templates

Show built-in templates and explain "Save as Template."

## 15. Search

The Lists home screen has a persistent search field. It filters by
list title or any item's text within that list (case-insensitive), so
"which list has milk on it" is as answerable as "which list is named
Groceries." A distinct empty state explains when a search has no
matches, separate from the "no lists yet" empty state. Clearing the
search restores the full list.

## 16. Undo and Confirmation

Every destructive action has either a confirmation step or an undo
path, chosen per action:

-   **Delete list:** confirm, then undo via a snackbar action.
-   **Delete item:** no confirmation (too frequent an action for that
    friction to be worth it) --- undo via a snackbar action instead.
-   **Clear completed:** confirm (a bulk action), then undo restores
    every cleared item exactly.
-   **Delete section, delete template:** confirm only; these are less
    frequent, more deliberate actions where a dialog is proportionate.

Undo always restores the exact original row (id, text, section,
sort order, and completion), not an approximation.

## 17. Appearance

The app follows the system's light/dark setting automatically. Dark
mode uses a deliberately designed dark palette derived from the same
accent color as light mode (via Material 3's tonal color system), not
a mechanical inversion. All screens read colors through the active
theme, so there is nothing to configure per-screen.

## 18. Non-Goals for MVP

Not part of MVP unless explicitly promoted into `PLAN.md`:

-   multi-user collaboration;
-   accounts;
-   cloud sync;
-   social features;
-   recurring reminders;
-   complex task management;
-   due dates/project management;
-   attachments;
-   comments;
-   subscriptions;
-   automatic background AI changes.

## 19. Success Criteria

The MVP succeeds if a user can reliably:

1.  create and use a manual checklist;
2.  reorder and complete items;
3.  reuse templates;
4.  describe a list in natural language;
5.  review AI output;
6.  create the AI output as a normal list;
7.  close/reopen the app without losing local data.

The product should feel useful even if the AI service is unavailable.
