## Why

My Notes and Shared list tabs render a blank `List` when there are no rows. A first-launch vault and an empty shared inbox look identical — empty chrome after loading — so users get no explanation and no visual cue that the screen is working. This is a focused UI polish on top of the existing list layout.

## What Changes

- Add a reusable `EmptyPlaceholderView` that takes an SF Symbol name, title, and description and renders Apple’s empty-state pattern (`ContentUnavailableView`: image + title + description, no action button)
- Show that placeholder on **My Notes** when owned notes have finished loading with no error and the list is empty
- Show that placeholder on **Shared** when shared notes have finished loading with no error and the list is empty
- Pass distinct localized copy and tab-matching symbols into the same view
- Keep toolbar Settings / Create, pull-to-refresh, loading spinner, and error text unchanged
- Do not show the placeholder during loading or when an error is displayed

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `notes-flow`: Empty list chrome for My Notes and Shared segments via a parameterized placeholder view

## Impact

- `Packages/NotesFlow/Sources/NotesFlow/` — new `EmptyPlaceholderView`; `NoteListView` shows it per segment when empty
- `Packages/NotesFlow/Sources/NotesFlow/Resources/Localizable.xcstrings` — empty title/description keys for both segments
- `Packages/NotesFlow/Tests/NotesFlowTests/` — source/localization tests for the placeholder and list wiring
- `DefaultNoteListViewModel` API unchanged unless a “has loaded” flag is needed so Shared does not flash empty on first tab visit
- No repository, sync, navigation, or sharing behavior changes
