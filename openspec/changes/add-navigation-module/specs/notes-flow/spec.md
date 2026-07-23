## ADDED Requirements

### Requirement: NotesDependencyProviding protocol

`NotesFlow` SHALL expose a public `@MainActor` protocol `NotesDependencyProviding` for dependencies required by notes screens. Concrete implementations SHALL NOT be public from the `NotesFlow` package.

#### Scenario: Protocol is public

- **WHEN** a consumer imports `NotesFlow`
- **THEN** `NotesDependencyProviding` is accessible

### Requirement: NotesNavigation view builder

`NotesFlow` SHALL provide an internal `NotesNavigation` type with a static `view(for:deps:)` method that maps each `NotesRoute` case to the corresponding SwiftUI screen using `any NotesDependencyProviding`.

#### Scenario: List route builds NoteListView

- **WHEN** `NotesNavigation.view(for: .list, deps:)` is called
- **THEN** a `NoteListView` is produced

### Requirement: NotesFlow depends on NotesFlowRoutes

The `NotesFlow` UI target SHALL depend on `NotesFlowRoutes` for `NotesRoute` and on `NavigationProtocol` only as needed for routing types. It SHALL NOT depend on the `Navigation` router implementation target.

#### Scenario: NotesFlow links NotesFlowRoutes

- **WHEN** the `NotesFlow` target is built
- **THEN** it imports `NotesFlowRoutes`
