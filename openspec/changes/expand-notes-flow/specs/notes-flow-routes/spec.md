## ADDED Requirements

### Requirement: NotesRoute detail case

`NotesRoute` SHALL include a `.detail(noteID: UUID)` case for the note detail screen.

#### Scenario: Detail route is defined

- **WHEN** `NotesRoute` is defined
- **THEN** it includes `.detail(noteID:)` with an associated `UUID` value

#### Scenario: Detail route conforms to Route

- **WHEN** `NotesRoute.detail(noteID:)` is used with navigation APIs
- **THEN** it satisfies `Route` (`Hashable`, `Sendable`)

### Requirement: NotesRoute create case

`NotesRoute` SHALL include a `.create` case for the new-note screen.

#### Scenario: Create route is defined

- **WHEN** `NotesRoute` is defined
- **THEN** it includes a `.create` case with no associated values

#### Scenario: Create route conforms to Route

- **WHEN** `NotesRoute.create` is used with navigation APIs
- **THEN** it satisfies `Route` (`Hashable`, `Sendable`)
