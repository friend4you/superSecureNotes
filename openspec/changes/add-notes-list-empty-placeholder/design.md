## Context

`NoteListView` uses a `TabView` with My Notes and Shared lists. Both wrap content in a shared `noteList` helper (`List` + loading row + error text + `.refreshable`). When a segment has zero rows, the list is blank.

`DefaultNoteListViewModel` exposes `notes`, `sharedNotes`, `isLoading`, and `errorMessage`. `refresh()` sets `isLoading`; `reloadSummaries()` / `reloadSharedSummaries()` (on appear and tab switch) do not. Shared starts as `[]` with `isLoading == false`, so a naive `isEmpty` check would flash empty chrome before the first shared load finishes.

iOS 17+ is the floor (`ContentUnavailableView` is available). List views are source-tested in `NoteListViewTests`; ViewModel behavior is unit-tested. Strict TDD applies.

## Goals / Non-Goals

**Goals:**

- One dumb placeholder view: SF Symbol + title + description, parameterized by the parent
- Apple empty-state layout via `ContentUnavailableView` (no action button)
- Distinct copy and tab-matching symbols for My Notes vs Shared
- Show placeholder only when that segment has loaded, is not loading, has no error, and has zero rows
- Keep toolbar, pull-to-refresh, loading, and error behavior

**Non-Goals:**

- Create / CTA button on the empty view (toolbar `+` already creates an owned note)
- Search-no-results, attachment, or other empty surfaces
- Changing Shared-tab `+` behavior
- Repository, sync, or navigation changes
- Custom illustration assets

## Decisions

### 1. Reusable `EmptyPlaceholderView` with three parameters

Add `EmptyPlaceholderView` in `NotesFlow` taking `systemImage: String`, `title: String`, and `description: String`. Internally wrap `ContentUnavailableView` with a `Label` (verbatim title + system image) and verbatim description text. The convenience `ContentUnavailableView(_:systemImage:description:)` initializer expects `String.LocalizationValue` and would re-localize already-translated strings. The view does not localize, know which tab it is on, or own a view model.

Call sites pass already-localized strings via `NotesFlowUILocalization.localized`.

**Alternatives considered:**

- Two hardcoded empty views — rejected; layout is identical
- Content struct / enum of cases — extra types for two call sites
- Localizing inside the placeholder — rejected; keeps the view reusable and dumb

### 2. Overlay on the existing `List`, not a list row

Do not place `ContentUnavailableView` inside `List` content — SwiftUI treats it as a row and it sits at the top instead of centering.

Keep the current `List` + `.refreshable` structure. Overlay the placeholder when that segment should show empty. Use `.allowsHitTesting(false)` on the overlay so pull-to-refresh still reaches the list.

Loading spinner and error text stay as list rows (unchanged). Overlay is gated off during those states.

**Alternatives considered:**

- Replace `List` with the placeholder when empty — duplicates `.refreshable` and splits loading/error layout
- Empty row text in the list — looks like a broken cell, not Apple empty chrome

### 3. Per-segment “has loaded” flags on the view model

Add `hasLoadedMyNotes` and `hasLoadedSharedNotes` (set `true` after `reloadSummaries` / `reloadSharedSummaries` complete, success or failure). Expose computed visibility:

- `showsMyNotesEmptyPlaceholder` — loaded, `!isLoading`, no `errorMessage`, `notes.isEmpty`
- `showsSharedEmptyPlaceholder` — same for shared

`NoteListView` binds overlay visibility to those flags. This is the ViewModel seam for TDD; the view stays a wiring layer.

Without these flags, the Shared tab would show “No Shared Notes” on first visit before `listSharedNotes()` returns.

**Alternatives considered:**

- `isEmpty && !isLoading` only — Shared flashes empty because tab switch does not set `isLoading`
- Set `isLoading` on every tab switch — noisy spinner for an instant local read

### 4. Distinct data, same view

| Segment | Symbol (match tab item) | Title key | Description key |
|---------|-------------------------|-----------|-----------------|
| My Notes | `list.bullet.clipboard` | `notes.list.empty.myNotes.title` | `notes.list.empty.myNotes.message` |
| Shared | `rectangle.stack.badge.person.crop` | `notes.list.empty.shared.title` | `notes.list.empty.shared.message` |

English copy:

- My Notes: “No Notes” / “Create your first encrypted note.”
- Shared: “No Shared Notes” / “Notes people share with you will show up here.”

No button on either placeholder.

### 5. Testing

- ViewModel unit tests for empty-visibility flags (loading, error, not-yet-loaded, empty, non-empty) per segment
- Source tests: `EmptyPlaceholderView` wraps `ContentUnavailableView` with the three parameters; `NoteListView` overlays it with the correct symbols and localization keys; overlay is not inside `ForEach`
- Localization catalog tests for the four new keys
- Follow red → green → refactor; test tasks immediately before implementation tasks

## Risks / Trade-offs

- **[Shared empty flash without load flags]** → Mitigation: `hasLoadedSharedNotes` must be false until the first `reloadSharedSummaries()` finishes
- **[Overlay blocks pull-to-refresh]** → Mitigation: `.allowsHitTesting(false)` on the placeholder overlay
- **[Empty vs error]** → Mitigation: never show the placeholder when `errorMessage != nil`, even if the array is empty
- **[Brief empty then spinner on first My Notes appear]** → `onAppear` reloads locally then `.task` `refresh()` sets `isLoading`. Visibility uses `!isLoading`, so empty hides during refresh. Acceptable; do not restructure appear/refresh in this change

## Migration Plan

UI-only. No data migration. Roll forward by shipping the view; roll back by removing the overlay and flags.

## Open Questions

None. Copy can be tweaked during implementation without changing the design.
