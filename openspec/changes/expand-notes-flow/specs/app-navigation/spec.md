## ADDED Requirements

### Requirement: App provides NoteRepository

`AppDependencies` SHALL expose a `noteRepository: any NoteRepository` constructed as `NetworkNoteRepository` or DEBUG `FileNoteRepository` per stub configuration.

#### Scenario: App dependencies expose note repository

- **WHEN** `AppDependencies` is initialized
- **THEN** `noteRepository` is available for composition wiring

### Requirement: NotesFlowDependencies receives note repository

`AppComposition` SHALL pass `infrastructure.noteRepository` to `NotesFlowDependencies` alongside existing auth, vault session, and navigator dependencies.

#### Scenario: Notes composition wires note repository

- **WHEN** `AppComposition` is initialized
- **THEN** `NotesFlowDependencies` receives the same `noteRepository` instance as `AppDependencies`

### Requirement: App links NoteRepository product

The `superSecureNotes` app target SHALL link `NoteRepository` and `NoteRepositoryProtocol` products if not already linked.

#### Scenario: App builds with NoteRepository

- **WHEN** the app target is built
- **THEN** it links the `NoteRepository` library product
