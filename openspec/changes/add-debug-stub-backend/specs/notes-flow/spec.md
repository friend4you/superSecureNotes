## ADDED Requirements

### Requirement: NotesFlow dependency injection for logout

`NotesFlow` SHALL extend `NotesDependencyProviding` with a `makeNoteListViewModel()` factory method. `NotesFlowDependencies` SHALL accept `authRepository: any AuthRepository` and `vaultSession: any VaultSessionProtocol` in its initializer, matching the dependency injection pattern used by `AuthFlowDependencies`. The `NotesFlow` target SHALL depend on `AuthRepositoryProtocol` and `VaultSessionProtocol`.

#### Scenario: NotesFlowDependencies conforms to extended protocol

- **WHEN** `NotesFlowDependencies` is constructed with auth repository and vault session
- **THEN** it satisfies `NotesDependencyProviding` and can produce a note list view model

#### Scenario: NotesFlow links auth and session protocol packages

- **WHEN** the `NotesFlow` package is built
- **THEN** it compiles with dependencies on `AuthRepositoryProtocol` and `VaultSessionProtocol`

### Requirement: NoteListViewModel protocol and default implementation

`NotesFlow` SHALL define a `@MainActor` `NoteListViewModel` protocol conforming to `Observable` with a `logout() async` method. It SHALL provide `DefaultNoteListViewModel` that calls `authRepository.logout()` and `vaultSession.clear()` on logout.

#### Scenario: Logout clears auth and vault session

- **WHEN** `logout()` is called on `DefaultNoteListViewModel` with an active session
- **THEN** `authRepository.logout()` and `vaultSession.clear()` are both invoked

#### Scenario: Logout is async and completes without throwing on success

- **WHEN** `logout()` is called with valid stub dependencies
- **THEN** the method completes without error

### Requirement: DEBUG-only logout button on NoteListView

`NoteListView` SHALL accept a `DefaultNoteListViewModel` via initializer (replacing the parameterless initializer for routed usage). In DEBUG builds only, the view SHALL display a logout button that triggers `viewModel.logout()`. The logout button SHALL NOT appear in Release builds.

#### Scenario: DEBUG build shows logout button

- **WHEN** `NoteListView` is rendered in a DEBUG build
- **THEN** a logout control is visible in the view hierarchy

#### Scenario: Release build hides logout button

- **WHEN** `NoteListView` is rendered in a Release build
- **THEN** no logout control is present in the view hierarchy

#### Scenario: Logout button triggers view model

- **WHEN** the user taps the logout button in DEBUG
- **THEN** `DefaultNoteListViewModel.logout()` is invoked

### Requirement: App wires notes dependencies with auth and session

`AppComposition` SHALL pass `infrastructure.authRepository` and `infrastructure.vaultSession` to `NotesFlowDependencies`.

#### Scenario: App composition provides auth and vault session to notes

- **WHEN** `AppComposition` is initialized
- **THEN** `NotesFlowDependencies` receives the same auth repository and vault session instances used by auth flow

#### Scenario: Logout returns user to login via root navigation

- **WHEN** the user taps logout on the notes screen in stub mode
- **THEN** `VaultSession.isActive` becomes false and the app root navigates to `AuthRoute.login`
