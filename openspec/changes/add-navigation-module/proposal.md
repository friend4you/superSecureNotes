## Why

Feature modules (`AuthFlow`, `NotesFlow`) own their screens but the app has no unified way to navigate between them, push routes from outside a module, or react to session changes at the root. A dedicated Navigation package with a shared `Route` protocol, per-module route libraries, and protocol-based dependencies gives each feature a stable navigation contract without coupling modules to `AppDependencies`.

## What Changes

- Add Swift Package `Navigation` with `NavigationProtocol` (contracts) and `Navigation` (router, registry, `NavigationHost`)
- Define `Route` protocol (`Hashable`, `Sendable`) and `NavigationRouting` (`setRoot`, `push`, `present`, `pop`, `popToRoot`)
- Store module routes directly in SwiftUI `NavigationPath` (no `RouteBox` type erasure)
- Add route registry: maps concrete route types to `view(for:deps:)` builders registered at app startup
- Add `AuthFlowRoutes` target with `AuthRoute`; refactor `AuthFlowUI` to use app-level routing instead of in-package `NavigationLink` (**BREAKING** for auth screen wiring)
- Add `NotesFlowRoutes` target with `NotesRoute`; add `NotesDependencyProviding` and `NotesNavigation` in `NotesFlow`
- Add `AuthFlowDependencyProviding` in `AuthFlowProtocol` / `AuthFlowUI` and `AuthNavigation.view(for:deps:)`
- App implements module dependency protocols (`AppAuthDependencies`, `AppNotesDependencies`); modules never receive `AppDependencies`
- App observes `VaultSession.changes` and instructs the router (`setRoot` to auth or main entry routes)
- Support push, sheet, and full-screen modal presentation via router API
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

- `navigation`: Navigation SPM package — `Route`, `NavigationRouting`, `NavigationPath` router storage, route registry, `NavigationHost`, presentation APIs
- `auth-flow-routes`: `AuthFlowRoutes` library — `AuthRoute` enum for cross-module auth navigation
- `auth-flow-ui`: Auth routing refactor — `AuthFlowDependencyProviding`, `AuthNavigation.view(for:deps:)`, remove internal `NavigationLink` navigation
- `notes-flow-routes`: `NotesFlowRoutes` library — `NotesRoute` enum for cross-module notes navigation
- `notes-flow`: `NotesDependencyProviding` and `NotesNavigation.view(for:deps:)` in `NotesFlow`
- `app-navigation`: App composition — session-driven root, module dependency protocol implementations, route registration

### Modified Capabilities

<!-- No archived main specs to modify; prior change specs remain historical -->

## Impact

- `Packages/Navigation/` — new package (`NavigationProtocol` + `Navigation` targets + tests)
- `Packages/AuthFlow/` — new `AuthFlowRoutes` target; `AuthFlowUI` navigation refactor; `AuthFlowDependencyProviding`
- `Packages/NotesFlow/` — new `NotesFlowRoutes` target; `NotesDependencyProviding`, `NotesNavigation`
- `superSecureNotes/RootView.swift` — replace ad-hoc `NavigationStack` / session branching with `NavigationHost` + router
- `superSecureNotes.xcodeproj` — link `Navigation`, `AuthFlowRoutes`, `NotesFlowRoutes`
- Other feature modules can depend on `*Routes` targets to navigate without importing UI
- Out of scope: deep linking / URL parsing (future module); `Route` is `Hashable` to support it later
