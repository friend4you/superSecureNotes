## 1. Stub Backend — InMemoryAuthRepository

- [ ] 1.1 Write failing tests for `InMemoryAuthRepository`: register stores session, login stores session and user, logout clears state, refreshSession throws when not authenticated (`superSecureNotesTests/InMemoryAuthRepositoryTests.swift`)
- [ ] 1.2 Implement `InMemoryAuthRepository` actor in `superSecureNotes/Stub/InMemoryAuthRepository.swift`; make tests pass

## 2. Stub Backend — FileVaultRepository

- [ ] 2.1 Write failing tests for `FileVaultRepository`: write/read roundtrip, headerNotFound when missing, header survives new repository instance (`superSecureNotesTests/FileVaultRepositoryTests.swift`)
- [ ] 2.2 Implement `FileVaultRepository` actor in `superSecureNotes/Stub/FileVaultRepository.swift` with Application Support file storage; make tests pass

## 3. Stub Backend — App wiring

- [ ] 3.1 Write failing tests for `StubBackendConfiguration.isEnabled` when `-UseStubBackend` is present vs absent (`superSecureNotesTests/StubBackendConfigurationTests.swift`)
- [ ] 3.2 Add `StubBackendConfiguration` and conditional repository selection in `AppDependencies`; make tests pass
- [ ] 3.3 Write failing test: stub mode still uses `SecureCryptoVaultAuthenticator` and `VaultSession` (`superSecureNotesTests/AppDependenciesTests.swift`)
- [ ] 3.4 Verify `AppDependencies` constructs real crypto/session types in stub mode; make test pass

## 4. NotesFlow — Package dependencies

- [ ] 4.1 Add `AuthFlow` and `VaultSession` package dependencies to `NotesFlow/Package.swift`; add `AuthRepositoryProtocol` and `VaultSessionProtocol` to `NotesFlow` target

## 5. NotesFlow — ViewModel and dependency injection

- [ ] 5.1 Write failing tests for `DefaultNoteListViewModel.logout()`: calls auth logout and vault session clear (`NotesFlowTests/DefaultNoteListViewModelTests.swift`)
- [ ] 5.2 Add `NoteListViewModel` protocol and `DefaultNoteListViewModel` in `NotesFlow`; make tests pass
- [ ] 5.3 Write failing test: `NotesFlowDependencies` conforms to extended `NotesDependencyProviding` with `makeNoteListViewModel()` (`NotesFlowTests/NotesFlowDependenciesTests.swift`)
- [ ] 5.4 Extend `NotesDependencyProviding` and `NotesFlowDependencies` with `authRepository`, `vaultSession`, and factory method; make tests pass

## 6. NotesFlow — Logout UI

- [ ] 6.1 Write failing test: `NoteListView` accepts view model via initializer (`NotesFlowTests/NoteListViewTests.swift`)
- [ ] 6.2 Update `NoteListView` to accept `DefaultNoteListViewModel`; add DEBUG-only logout toolbar button calling `logout()`; make tests pass
- [ ] 6.3 Update `NotesNavigation.listView(deps:)` to construct view model from dependencies

## 7. App composition

- [ ] 7.1 Write failing test: `AppComposition` passes auth repository and vault session to `NotesFlowDependencies` (`superSecureNotesTests/AppCompositionTests.swift`)
- [ ] 7.2 Update `AppComposition` to wire `authRepository` and `vaultSession` into `NotesFlowDependencies`; make test pass
- [ ] 7.3 Write failing integration test: logout on notes clears vault session and triggers login root (`superSecureNotesTests/LogoutFlowTests.swift`)
- [ ] 7.4 Verify end-to-end logout navigation via `SessionRootNavigation` + `vaultSession.changes`; make test pass

## 8. Xcode scheme and manual verification

- [ ] 8.1 Add `-UseStubBackend` launch argument to Debug scheme in `superSecureNotes.xcodeproj`
- [ ] 8.2 Manual: register with stub → land on notes → logout → login → kill app → login with same password → notes
