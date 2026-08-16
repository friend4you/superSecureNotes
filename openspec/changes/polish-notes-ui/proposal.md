## Why

Notes screens have accumulated UI friction: sync status competes with note titles, detail screens duplicate the title in the form and toolbar, destructive actions crowd the navigation bar, settings pushes instead of presenting modally, and logout is hidden behind a DEBUG-only list toolbar button. A focused layout pass will make list and detail screens calmer, more consistent, and production-ready without changing sync or repository behavior.

## What Changes

- **Note list (My Notes):** Move sync indicator to the trailing edge of each row as an icon-only badge (always visible for pending and synced states); keep long-press context menus unchanged
- **Note list (Shared):** No sync indicator on rows
- **Note list toolbar:** Settings becomes a leading `gearshape` icon button; create (`+`) stays trailing primary; remove logout from the list toolbar (including removal of `#if DEBUG` gating)
- **Settings:** Open via `present(AuthRoute.settings, style: .sheet)` instead of push; wrap in `NavigationStack` with a Done dismiss action
- **Settings screen:** Add production logout row wired to the existing `performLogout` reset flow
- **Note detail:** Restore editable title in the form; show full sync status (icon + text) in `.principal`; keep Save and `⋯` overflow menu; remove trailing toolbar sync icon
- **Shared note detail:** Show "shared by" text in `.principal`; restore read-only title in the form; keep `⋯` delete menu
- **Create note:** Inline static "New Note" navigation title only; restore editable title in the form
- **`NoteSyncStatusLabel`:** Support icon-only display mode for list rows and detail toolbar

## Capabilities

### New Capabilities

- `auth-flow-ui`: Settings sheet presentation chrome (NavigationStack, Done dismiss) and production logout action on the settings screen

### Modified Capabilities

- `notes-flow`: List row layout, toolbar placement, settings presentation trigger, detail/create/shared detail layouts, overflow menus, and sync indicator placement

## Impact

- `Packages/NotesFlow/Sources/NotesFlow/NoteListView.swift` — row layout, toolbar icons, remove logout
- `Packages/NotesFlow/Sources/NotesFlow/NoteSyncStatusLabel.swift` — icon-only mode
- `Packages/NotesFlow/Sources/NotesFlow/NoteDetailView.swift` — form title, principal sync status, overflow menu
- `Packages/NotesFlow/Sources/NotesFlow/SharedNoteDetailView.swift` — principal shared-by, form title, delete menu
- `Packages/NotesFlow/Sources/NotesFlow/CreateNoteView.swift` — inline nav title, form title field
- `Packages/NotesFlow/Sources/NotesFlow/ViewModels/DefaultNoteListViewModel.swift` — settings via sheet present
- `Packages/NotesFlow/Sources/NotesFlow/ViewModels/DefaultSharedNoteDetailViewModel.swift` — delete + pop
- `Packages/AuthFlow/Sources/AuthFlowUI/Views/BiometricSettingsView.swift` — sheet chrome, logout row
- `Packages/AuthFlow/Sources/AuthFlowProtocol/ViewModels/DefaultBiometricSettingsViewModel.swift` — logout action
- `Packages/AuthFlow/Sources/AuthFlowProtocol/Protocols/AuthFlowDependencyProviding.swift` and `AuthFlowDependencies` — wire `performLogout` into settings VM factory
- Tests in `NotesFlowTests`, `AuthFlowUITests`, and related view model tests
- No backend, sync model, or `NoteRepository` API changes
