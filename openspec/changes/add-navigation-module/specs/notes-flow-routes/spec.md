## ADDED Requirements

### Requirement: NotesFlowRoutes package target

The `NotesFlow` package SHALL expose a library product `NotesFlowRoutes` backed by a target that depends only on `NavigationProtocol`. The target SHALL define a public `NotesRoute` enum conforming to `Route`.

#### Scenario: NotesFlowRoutes builds independently

- **WHEN** the `NotesFlowRoutes` target is built
- **THEN** it compiles with only `NavigationProtocol` as a project dependency

#### Scenario: NotesRoute includes list entry

- **WHEN** `NotesRoute` is defined
- **THEN** it includes a case for the note list screen

### Requirement: NotesFlowRoutes import boundary

Other modules that need to navigate to notes screens SHALL depend on `NotesFlowRoutes` only, not on the full `NotesFlow` UI target.

#### Scenario: Cross-module notes navigation without UI import

- **WHEN** a consumer imports `NotesFlowRoutes`
- **THEN** it can reference `NotesRoute` without importing `NotesFlow`
