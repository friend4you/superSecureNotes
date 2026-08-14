## Why

Notes screens have accumulated UI friction: sync status competes with note titles, detail screens duplicate the title in the form and toolbar, destructive actions crowd the navigation bar, settings pushes instead of presenting modally, and logout is hidden behind a DEBUG-only list toolbar button. A focused layout pass will make list and detail screens calmer, more consistent, and production-ready without changing sync or repository behavior.

## What Changes

- **Note list (My Notes):** Move sync indicator to the trailing edge of each row as an icon-only badge (always visible for pending and synced states); keep long-press context menus unchanged
- **Note list (Shared):** No sync indicator on rows
- **Note list toolbar:** Settings becomes a leading `gearshape` icon button; create (`+`) stays trailing primary; remove logout from the list toolbar (including removal of `#if DEBUG` gating)
- **Settings:** Open via `present(AuthRoute.settings, style: .sheet)` instead of push; wrap in `NavigationStack` with a Done dismiss action
- **Settings screen:** Add production logout row wired to the existing `performLogout` reset flow
- **Note detail:** Remove the in-form title section; bind an editable title in the navigation bar; move sync to a trailing toolbar icon; collapse Share and Delete into a `⋯` overflow `Menu`; keep Save as primary action
- **Shared note detail:** Show note title in the navigation bar (read-only); de-emphasize "shared by" as caption metadata above the body; add `⋯` menu with Delete and confirmation; pop on success
- **Create note:** Same editable navigation-bar title pattern as detail; remove the in-form title section
- **`NoteSyncStatusLabel`:** Support icon-only display mode for list rows and detail toolbar

## Capabilities

### New Capabilities

- `auth-flow-ui`: Settings sheet presentation chrome (NavigationStack, Done dismiss) and production logout action on the settings screen

### Modified Capabilities

- `notes-flow`: List row layout, toolbar placement, settings presentation trigger, detail/create/shared detail layouts, overflow menus, and sync indicator placement

## Impact

- `Packages/NotesFlow/Sources/NotesFlow/NoteListView.swift` — row layout, toolbar icons, remove logout
- `Packages/NotesFlow/Sources/NotesFlow/NoteSyncStatusLabel.swift` — icon-only mode
- `Packages/NotesFlow/Sources/NotesFlow/NoteDetailView.swift` — nav title field, overflow menu, toolbar sync
- `Packages/NotesFlow/Sources/NotesFlow/SharedNoteDetailView.swift` — nav title, subtle owner, delete menu
- `Packages/NotesFlow/Sources/NotesFlow/CreateNoteView.swift` — editable nav title
- `Packages/NotesFlow/Sources/NotesFlow/ViewModels/DefaultNoteListViewModel.swift` — settings via sheet present
- `Packages/NotesFlow/Sources/NotesFlow/ViewModels/DefaultSharedNoteDetailViewModel.swift` — delete + pop
- `Packages/AuthFlow/Sources/AuthFlowUI/Views/BiometricSettingsView.swift` — sheet chrome, logout row
- `Packages/AuthFlow/Sources/AuthFlowProtocol/ViewModels/DefaultBiometricSettingsViewModel.swift` — logout action
- `Packages/AuthFlow/Sources/AuthFlowProtocol/Protocols/AuthFlowDependencyProviding.swift` and `AuthFlowDependencies` — wire `performLogout` into settings VM factory
- Tests in `NotesFlowTests`, `AuthFlowUITests`, and related view model tests
- No backend, sync model, or `NoteRepository` API changes
