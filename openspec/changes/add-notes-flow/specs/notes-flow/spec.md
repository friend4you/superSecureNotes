## ADDED Requirements

### Requirement: NotesFlow package module boundary

The project SHALL provide a Swift Package `NotesFlow` with a single library product `NotesFlow` backed by one SwiftUI target. The package SHALL support iOS 17+ and macOS 13+. The package SHALL have no dependencies on other project packages (`SecureCrypto`, `VaultSession`, or future modules).

#### Scenario: Package builds with NotesFlow target

- **WHEN** the `NotesFlow` package is built
- **THEN** the `NotesFlow` target compiles successfully on supported platforms

#### Scenario: Package has no internal project dependencies

- **WHEN** `NotesFlow` is built
- **THEN** it does not import or link `SecureCrypto`, `VaultSession`, or other project packages

### Requirement: NoteListView placeholder screen

The module SHALL expose a public SwiftUI view `NoteListView` with a public parameterless initializer. The view body SHALL display the text `"Note list"` as its primary visible content.

#### Scenario: NoteListView is publicly constructible

- **WHEN** a consumer imports `NotesFlow` and creates `NoteListView()`
- **THEN** the type compiles and can be used in a SwiftUI view hierarchy

#### Scenario: NoteListView shows placeholder label

- **WHEN** `NoteListView` is rendered
- **THEN** the user-visible text includes `"Note list"`

### Requirement: SwiftUI preview support

The `NotesFlow` package SHALL include a `#Preview` for `NoteListView` so the screen can be previewed in Xcode without launching the app.

#### Scenario: NoteListView preview compiles

- **WHEN** the `NotesFlow` package is built with SwiftUI previews enabled
- **THEN** the `NoteListView` preview provider compiles successfully

### Requirement: App-only import boundary

Only the `superSecureNotes` app target SHALL link the `NotesFlow` package product. Other Swift packages in the project SHALL NOT depend on `NotesFlow` in this change.

#### Scenario: App target links NotesFlow

- **WHEN** the `superSecureNotes` app target is built
- **THEN** it links the `NotesFlow` library product

#### Scenario: App presents NoteListView

- **WHEN** the app launches its primary navigation entry point
- **THEN** `NoteListView` from `NotesFlow` is shown in the view hierarchy

### Requirement: NotesFlow does not implement note data or crypto

The `NotesFlow` module SHALL NOT load, persist, encrypt, or decrypt note content in this change. It SHALL provide UI scaffolding only.

#### Scenario: No note persistence API on NotesFlow

- **WHEN** the public API of `NotesFlow` is inspected
- **THEN** it does not include note file I/O, encryption, or `VaultSession` access methods
