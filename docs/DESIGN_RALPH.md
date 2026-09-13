# PromptList Design Ralph Loop

## Purpose

PromptList is functionally complete.

The purpose of this Ralph run is NOT to add ordinary product features.

The purpose is to repeatedly improve:

- visual identity
- look and feel
- interaction design
- typography
- color
- surfaces
- backgrounds
- buttons and controls
- spacing
- hierarchy
- animation
- empty states
- list presentation
- template presentation
- AI-generation experience
- dark mode
- polish and consistency

Each iteration should leave the app more distinctive, coherent, professional, and enjoyable to use.

## Core Rule

Each Ralph iteration must begin by evaluating the application AS IT EXISTS NOW.

Do not blindly continue a previously imagined redesign.

The app will change between iterations.

Inspect what currently exists, decide what is now the weakest or highest-value design opportunity, and improve that.

## Product Stability

Functional behavior is considered complete.

Preserve existing functionality.

Do not introduce significant new product features unless they are necessary to support a design or interaction improvement.

Do not change:

- persistence behavior
- AI contracts
- core list behavior
- template behavior
- navigation architecture
- database schema

unless required to safely support the chosen design improvement.

Design evolution must not destabilize the product.

## Design Goal

PromptList should feel like a professionally designed commercial app rather than a generated Flutter project.

Target qualities:

- distinctive
- classy
- polished
- tactile
- calm
- modern
- confident
- cohesive
- slightly unexpected
- visually memorable

Avoid looking:

- generic Material
- overly corporate
- childish
- gimmicky
- excessively futuristic
- like a chatbot
- like a typical purple-gradient AI app
- like a collection of default Flutter widgets

## Design Authority

Claude has broad authority to make visual decisions.

Do NOT ask the user to pick:

- exact colors
- corner radii
- font sizes
- icon placement
- surface treatments
- animation timing
- spacing
- button geometry
- illustration style

unless a decision would fundamentally change the product.

Make a strong design choice and evaluate it.

## Design System

Maintain ONE coherent design language.

Do not reinvent the app's visual identity every iteration.

When changing the design system, update existing components so the app remains cohesive.

Evaluate:

- color palette
- typography hierarchy
- spacing scale
- corner geometry
- elevation/shadows
- borders
- backgrounds
- button styles
- input controls
- checkbox treatment
- drag handles
- icons
- motion
- illustrations
- cards/surfaces
- navigation

Prefer reusable design-system components over one-off styling.

## Avoid Generic Flutter Styling

Actively avoid:

- default Material blue
- stereotypical AI purple
- large gradient headers
- everything inside Cards
- identical rounded rectangles
- default ElevatedButton styling everywhere
- default FloatingActionButton as the primary visual identity
- excessive pill controls
- arbitrary glassmorphism
- random gradients
- excessive shadows
- sparkles as the only AI motif

Using Material components internally is fine, but their final presentation should feel intentional.

## Backgrounds

Consider richer but restrained backgrounds.

Potential techniques:

- tonal layers
- subtle gradients
- paper-inspired texture
- abstract shapes
- very quiet patterns
- illustration
- soft depth
- contextual list artwork

Backgrounds must not interfere with content readability.

## AI-Generated Artwork

AI-generated assets are encouraged when appropriate.

Possible uses:

- empty states
- onboarding
- template artwork
- abstract list covers
- AI-create screen
- subtle decorative backgrounds
- category art

Maintain a consistent art direction.

Do not generate copyrighted characters or branded imagery simply because example lists reference them.

If image generation is unavailable, do not block the loop.

## Motion

Use animation intentionally.

Good candidates:

- completing an item
- adding an item
- drag/drop settle
- opening a list
- AI generation progress
- accepting AI preview
- template instantiation
- deleting/undoing
- transitions between key states

Keep animation subtle and fast.

Respect reduced-motion accessibility settings.

## Accessibility

Visual improvement must not reduce usability.

Maintain:

- sufficient contrast
- readable text
- large enough targets
- meaningful semantics
- text scaling support
- dark-mode readability
- non-color indicators for state

## Iteration Process

Every design iteration follows this process.

### 1. Inspect

Review the application and recent screenshots/tests.

Ask:

- What currently looks most generic?
- What screen feels weakest?
- Where is hierarchy unclear?
- Which interaction feels most default?
- Does anything feel inconsistent?
- What would make this feel like PromptList?
- What would a professional product designer improve next?

### 2. Generate Candidates

Identify 3-5 possible design improvements.

Examples might involve:

- visual system
- home screen
- list screen
- AI screen
- templates
- navigation
- empty states
- motion
- dark mode
- typography
- backgrounds
- controls

Do NOT automatically choose the largest change.

### 3. Select One Theme

Choose the improvement with the highest combination of:

- visual impact
- usability impact
- coherence
- uniqueness
- reasonable implementation risk

Each iteration should have ONE primary design theme.

Examples:

"Redesign list completion interactions."

"Give Templates a strong visual browsing identity."

"Replace generic app surfaces with a layered paper-inspired system."

These are examples only.

### 4. Implement

Implement the design improvement across all relevant components.

Prefer completing one coherent design concept rather than scattering small unrelated tweaks throughout the app.

### 5. Test

Run all existing automated tests.

Add/update tests when interaction behavior changes.

At minimum:

dart format .
flutter analyze
flutter test

Run relevant integration tests.

### 6. Visual QA

Inspect affected screens.

Check:

- light mode
- dark mode
- long content
- short content
- empty state
- small phone layout
- text scaling where relevant
- loading/error states

Fix visual regressions.

### 7. Record

Append a DESIGN entry to PROGRESS.md.

Record:

- what was improved
- why it was chosen
- important visual decisions
- what remains visually weak

This last point is especially important because it gives the next iteration a useful starting hypothesis without forcing it to follow it.

### 8. Commit

Commit the iteration's design work.

Example:

DESIGN-004: refine checklist interaction language

### 9. Push

Push immediately.

Verify the push succeeded.

The iteration is not complete until its changes are on the remote.

## Iteration Independence

The next iteration must reassess the app from scratch.

It may decide that the previous iteration exposed a new problem.

It does NOT need to follow the previous iteration's suggested next improvement.

PROGRESS.md is context, not a command.

## Design Escalation

Earlier iterations may make larger foundational changes.

As the run progresses, changes should generally become more refined.

A healthy progression may naturally look like:

early:
- design system
- palette
- typography
- major surfaces

middle:
- individual screens
- controls
- illustrations
- interaction language

late:
- consistency
- animation
- edge states
- spacing
- accessibility
- tiny polish

Do not artificially follow this sequence if the app needs something else.

## Final Iterations

As the iteration budget approaches its end, stop making broad redesigns.

Concentrate on:

- consistency
- visual defects
- awkward edge states
- accessibility
- animation polish
- dark mode
- typography
- spacing
- alignment
- performance
- final screenshots/QA

The final iteration should act as a design QA pass.

## Git Rules

Every iteration must end:

- tests passing
- working tree clean
- committed
- pushed

Never force-push.

Never accumulate multiple unpushed design iterations.

## Success Standard

At the end of the Ralph run, a person familiar with generic Flutter apps should NOT immediately assume this app was generated from a standard Flutter template.

PromptList should have a recognizable visual personality of its own.