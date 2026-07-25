## Why

Note sharing is a distinct user journey from browsing notes. A dedicated `ShareNote` Swift Package establishes the module boundary for share screens before encryption, recipient lookup, and cross-module navigation from `NotesFlow` are built. Starting with a parameterized route, placeholder screen, and view model wired through app-level route registration mirrors the proven `NotesFlow` pattern.

## What Changes

- Add a new Swift Package `ShareNote` with two library products: `ShareNote` (UI) and `ShareNoteRoutes` (route enum)
- Add `ShareNoteRoute.share(noteID: UUID)` conforming to `Route`
- Add `ShareNoteView` placeholder screen and `ShareNoteViewModel` protocol with `DefaultShareNoteViewModel` (depends on `Navigating` only)
- Add `ShareNoteDependencyProviding`, `ShareNoteDependencies`, `ShareNoteNavigation`, and `registerShareNoteRoutes` extension on `RouteRegistry`
- Register `ShareNoteRoute` in `AppComposition`; add to `verifyRegistered` — no push from `NotesFlow` yet
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

- `share-note-routes`: `ShareNoteRoutes` library — `ShareNoteRoute` enum for cross-module share navigation
- `share-note`: `ShareNote` package — `ShareNoteView`, view model, dependency providing, and navigation wiring
- `app-navigation`: App composition — register `ShareNoteRoute`, wire `ShareNoteDependencies`, update `verifyRegistered`

### Modified Capabilities

<!-- No archived main specs to modify; app-navigation delta extends change-level spec -->

## Impact

- `Packages/ShareNote/` — new package (`ShareNoteRoutes` + `ShareNote` targets + tests)
- `superSecureNotes.xcodeproj` — link `ShareNote` and `ShareNoteRoutes` products to app target
- `superSecureNotes/AppComposition.swift` — register share routes, add `ShareNoteDependencies`
- Out of scope: push from `NotesFlow`, `VaultSession`/`VaultRepository` integration, encryption, recipient lookup
