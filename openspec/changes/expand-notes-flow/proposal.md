## Why

`NotesFlow` is still a placeholder list screen. `NoteRepository` provides server-backed note blob persistence, `SecureCrypto` defines the `.note` format, and `ShareNote` scaffolds the share journey — but no screens load, edit, create, or navigate between notes. Users need a complete notes journey (list, detail, create, share, delete) with localization, TDD, and stub-backend support for offline development.

## What Changes

- Extend `NotesRoute` with `.detail(noteID:)`, `.create` (push presentation)
- Replace placeholder `NoteListView` with a real list showing note titles from `NoteRepository.listNotes()`
- Add `NoteDetailView` — always-editable title and body, Save (disabled when clean or title empty), Share toolbar button, Delete with confirmation, inline loading/error
- Add `CreateNoteView` — title, body, `PhotosPicker` and `fileImporter` for common attachment types, Save (requires non-empty title), pop on save
- List: pull-to-refresh, context menu (Share, Delete with confirmation), settings toolbar button with no action and `TODO` in code
- Share: present `ShareNoteRoute.share(noteID:)` as sheet from list context menu and detail toolbar; update `DefaultShareNoteViewModel.dismiss()` to call `dismissPresentation()`
- ViewModels orchestrate `NoteRepository` + `VaultSession` + `SecureCrypto` for encrypt/decrypt/assemble v1 (no separate service layer)
- Add `FileNoteRepository` DEBUG stub in app target; wire `NoteRepository` in `AppDependencies` when `-UseStubBackend` is set
- Add `NotesFlow` localization (`defaultLocalization`, string catalog, bundle test) following `AuthFlowUI` pattern
- Wire `noteRepository` through `NotesFlowDependencies` and `AppComposition`
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

<!-- No new top-level capability packages; behavior extends existing modules -->

### Modified Capabilities

- `notes-flow`: Full list, detail, and create screens with ViewModels, localization, crypto orchestration in ViewModels, share/delete navigation, settings stub button
- `notes-flow-routes`: `NotesRoute.detail(noteID:)` and `NotesRoute.create` cases
- `share-note`: Sheet dismiss via `dismissPresentation()`; reachable from notes list and detail
- `app-navigation`: `NoteRepository` wired in app composition; `NotesFlowDependencies` receives `noteRepository`
- `debug-stub-backend`: `FileNoteRepository` stub and conditional selection in `AppDependencies`

## Impact

- `Packages/NotesFlow/` — new views, ViewModels, localization resources, package dependencies (`NoteRepository`, `SecureCrypto`, `ShareNoteRoutes`)
- `Packages/NotesFlowRoutes/` — extended `NotesRoute` enum
- `Packages/ShareNote/` — `DefaultShareNoteViewModel.dismiss()` behavior change
- `superSecureNotes/Stub/` — `FileNoteRepository.swift`
- `superSecureNotes/AppDependencies.swift` — note repository selection
- `superSecureNotes/AppComposition.swift` — pass `noteRepository` to notes deps
- `superSecureNotes.xcodeproj` — link `NoteRepository` if not already linked to app
- Out of scope: `SettingsFlow` package, share encryption/recipients, rich text, attachment size limits, delete from list swipe (context menu only), network note repo in stub mode
