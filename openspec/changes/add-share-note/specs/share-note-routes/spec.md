## ADDED Requirements

### Requirement: ShareNoteRoutes package target

The `ShareNote` package SHALL expose a library product `ShareNoteRoutes` backed by a target that depends only on `NavigationProtocol`. The target SHALL define a public `ShareNoteRoute` enum conforming to `Route`.

#### Scenario: ShareNoteRoutes builds independently

- **WHEN** the `ShareNoteRoutes` target is built
- **THEN** it compiles with only `NavigationProtocol` as a project dependency

#### Scenario: ShareNoteRoute includes share entry with note ID

- **WHEN** `ShareNoteRoute` is defined
- **THEN** it includes a `share(noteID: UUID)` case for the share screen

### Requirement: ShareNoteRoutes import boundary

Other modules that need to navigate to share screens SHALL depend on `ShareNoteRoutes` only, not on the full `ShareNote` UI target.

#### Scenario: Cross-module share navigation without UI import

- **WHEN** a consumer imports `ShareNoteRoutes`
- **THEN** it can reference `ShareNoteRoute` without importing `ShareNote`
