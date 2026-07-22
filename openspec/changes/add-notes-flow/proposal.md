## Why

The app target is still a placeholder with no note-related UI. A dedicated Swift Package gives note screens a stable home separate from crypto and session infrastructure, so the app can navigate to note flows without growing the app target. Starting with a minimal `NoteListView` placeholder establishes the module boundary before list, detail, and create screens are built.

## What Changes

- Add a new Swift Package `NotesFlow` with a single `NotesFlow` library target (SwiftUI)
- Add a public `NoteListView` that displays placeholder text `"Note list"`
- Include `#Preview` support for `NoteListView` in the package
- Link `NotesFlow` in the Xcode project; only the app target imports it
- Wire app navigation to present `NoteListView`
- No dependencies on `SecureCrypto`, `VaultSession`, or other packages in v1

## Capabilities

### New Capabilities

- `notes-flow`: SwiftUI package for note user journeys — package boundary, `NoteListView` placeholder, preview support, app-only import

### Modified Capabilities

<!-- No existing main specs to modify -->

## Impact

- `Packages/NotesFlow/` — new package (`NoteListView` placeholder)
- `superSecureNotes.xcodeproj` — link `NotesFlow` product to app target
- `superSecureNotes/` — import `NotesFlow` and navigate to `NoteListView`
- Out of scope: note data loading, encryption, `VaultSession` integration, detail/create screens, ViewModels
