## 1. SecureCrypto recipient FEK wrap

- [ ] 1.1 Write failing tests: `wrapFEKForRecipient` produces `SSNF` v1 wire blob with 32-byte ephemeral key; rejects invalid public key length; roundtrip with `unwrapSharedFEK` recovers original FEK (`SecureCryptoTests/ShareFEKWrappingTests`)
- [ ] 1.2 Implement `wrapFEKForRecipient` and `unwrapSharedFEK` in `SecureCrypto` using X25519 + HKDF + existing `wrapKey`/`unwrapKey`

## 2. VaultRepository public key by email

- [ ] 2.1 Write failing tests: `VaultAPIClient` sends `GET /users/public-key?email=` with Bearer token; parses base64 public key on 200; maps `public_key_not_found` and rejects empty email (`VaultRepositoryTests/VaultAPIClientFetchPublicKeyByEmailTests`)
- [ ] 2.2 Add `fetchPublicKey(email:)` to `VaultRepository` protocol, `NetworkVaultRepository`, and `VaultAPIClient`
- [ ] 2.3 Write failing tests: `LocalVaultRepository.fetchPublicKey(email:)` returns 32 zero bytes (`VaultRepositoryTests/LocalVaultRepositoryFetchPublicKeyByEmailTests`)
- [ ] 2.4 Implement `LocalVaultRepository.fetchPublicKey(email:)` stub

## 3. NoteRepository sharing API

- [ ] 3.1 Write failing tests: `SharedNoteSummary` and `SharedNote` models; `NoteAPIClient` list shared, read shared, and share note request/response parsing (`NoteRepositoryTests/NoteSharingAPIClientTests`)
- [ ] 3.2 Add sharing DTOs and `NoteAPIClient` methods for `GET /notes/shared`, `GET /notes/shared/{id}`, `POST /notes/{id}/share`
- [ ] 3.3 Write failing tests: `NetworkNoteRepository` sharing methods delegate to API client; `LocalNoteRepository` stubs return empty list and throw `notSupported` (`NoteRepositoryTests/NoteSharingRepositoryTests`)
- [ ] 3.4 Extend `NoteRepository` protocol and implement sharing methods on network and local repositories; add `NoteRepositoryError.notSupported` if needed

## 4. ShareNote UI and view model

- [ ] 4.1 Write failing tests: `DefaultShareNoteViewModel.share()` loads note, blocks unsynced notes, fetches public key, wraps FEK, calls `shareNote`, dismisses on success; surfaces `publicKeyNotFound` error (`ShareNoteTests/DefaultShareNoteViewModelTests`)
- [ ] 4.2 Expand `ShareNoteDependencyProviding` / `ShareNoteDependencies` with `noteRepository`, `vaultRepository`, `vaultSession`; update `DefaultShareNoteViewModel`
- [ ] 4.3 Write failing tests: `ShareNoteView` renders email field and Share button; disables share while loading (`ShareNoteTests/ShareNoteViewTests`)
- [ ] 4.4 Replace placeholder `ShareNoteView` with share form UI and localization strings

## 5. NotesFlow shared list and detail

- [ ] 5.1 Write failing tests: `NotesRoute.sharedDetail(noteID:)` conforms to `Route` and is `Hashable` (`NotesFlowRoutesTests`)
- [ ] 5.2 Add `NotesRoute.sharedDetail(noteID: UUID)` case
- [ ] 5.3 Write failing tests: `DefaultNoteListViewModel` loads `sharedNotes` on Shared segment; `openSharedDetail` pushes `sharedDetail` route (`NotesFlowTests/DefaultNoteListViewModelSharedTests`)
- [ ] 5.4 Add `selectedSegment`, `sharedNotes`, shared loading to `DefaultNoteListViewModel` and segmented control to `NoteListView`
- [ ] 5.5 Write failing tests: `DefaultSharedNoteDetailViewModel.load()` calls `readSharedNote`, unwraps with identity key, populates read-only fields; view shows owner email and no Save button (`NotesFlowTests/SharedNoteDetailTests`)
- [ ] 5.6 Implement `DefaultSharedNoteDetailViewModel`, `SharedNoteDetailView`, and `NotesNavigation` mapping for `.sharedDetail`
- [ ] 5.7 Add localization strings for segmented control, shared list, shared detail owner label, and share errors

## 6. App composition wiring

- [ ] 6.1 Write failing tests: `ShareNoteDependencies` receives `noteRepository`, `vaultRepository`, `vaultSession`; shared note list works through app-wired `NotesFlowDependencies` (`AppCompositionTests`)
- [ ] 6.2 Wire expanded dependencies in `AppComposition` and `NotesFlowDependencies`

## 7. Final verification

- [ ] 7.1 Run full test suite; fix regressions
- [ ] 7.2 Manual smoke: share synced note by email; switch to Shared segment; open read-only shared detail with owner email visible
