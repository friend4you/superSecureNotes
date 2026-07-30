## 1. SecureCrypto — local note body format

- [ ] 1.1 Write failing tests: `assembleLocalNoteBody` / `parseLocalNoteBody` roundtrip; reject invalid magic/version; metadata parse without decryption (`Packages/SecureCrypto/Tests/SecureCryptoTests/Note/LocalNoteBodyTests.swift`)
- [ ] 1.2 Implement local note body assemble/parse helpers in `Packages/SecureCrypto/Sources/SecureCrypto/Note/`; make tests pass
- [ ] 1.3 Write failing tests: split wire blob via `parseNoteFile` then reassemble via `assembleNoteFile` preserves bytes (`Packages/SecureCrypto/Tests/SecureCryptoTests/Note/NoteFileSplitTests.swift`)
- [ ] 1.4 Add split/reassemble convenience helpers if needed; make tests pass

## 2. NoteRepository — corruptNote error

- [ ] 2.1 Write failing tests: `NoteRepositoryError.corruptNote` is `Equatable` (`Packages/NoteRepository/Tests/NoteRepositoryProtocolTests/NoteRepositoryErrorTests.swift`)
- [ ] 2.2 Add `corruptNote` case to `NoteRepositoryError`; make tests pass

## 3. VaultRepository — LocalVaultRepository

- [ ] 3.1 Write failing tests: write/read header roundtrip; `headerNotFound` when missing; survives new instance; atomic write; iCloud backup excluded; `fetchPublicKey` returns 32 zero bytes (`Packages/VaultRepository/Tests/VaultRepositoryTests/LocalVaultRepositoryTests.swift`)
- [ ] 3.2 Implement `LocalVaultRepository` actor in `Packages/VaultRepository/Sources/VaultRepository/LocalVaultRepository.swift`; make tests pass

## 4. NoteRepository — LocalNoteRepository

- [ ] 4.1 Write failing tests: write/read wire blob roundtrip; `listNotes` from directories; `deleteNote` removes directory; `noteNotFound` when missing; `corruptNote` when only one file present; `validationError` on empty data and noteID mismatch; atomic directory replace; iCloud backup excluded (`Packages/NoteRepository/Tests/NoteRepositoryTests/LocalNoteRepositoryTests.swift`)
- [ ] 4.2 Add `SecureCrypto` dependency to `NoteRepository` target in `Package.swift` if not present
- [ ] 4.3 Implement `LocalNoteRepository` actor in `Packages/NoteRepository/Sources/NoteRepository/LocalNoteRepository.swift`; make tests pass

## 5. App wiring — remove stubs, use local repos

- [ ] 5.1 Write failing tests: `AppDependencies` always constructs `LocalNoteRepository` and `LocalVaultRepository`; stub mode selects `InMemoryAuthRepository` only; non-stub DEBUG uses `NetworkAuthRepository` (`superSecureNotesTests/AppDependenciesTests.swift`)
- [ ] 5.2 Update `AppDependencies` to wire local repositories in all builds; make tests pass
- [ ] 5.3 Delete `superSecureNotes/Stub/FileNoteRepository.swift` and `superSecureNotes/Stub/FileVaultRepository.swift`
- [ ] 5.4 Remove or replace `superSecureNotesTests/FileNoteRepositoryTests.swift` and `FileVaultRepositoryTests.swift` if present
- [ ] 5.5 Write failing test: `AppComposition` still wires notes flow with local note repository (`superSecureNotesTests/AppCompositionTests.swift`)
- [ ] 5.6 Verify `AppComposition` passes `noteRepository` from `AppDependencies`; make test pass

## 6. Manual verification

- [ ] 6.1 DEBUG with `-UseStubBackend`: register → create note → kill app → login → note persists from `Application Support/superSecureNotes/notes/`
- [ ] 6.2 Verify `notes/{uuid}/` contains both `note` and `fek` files after save
- [ ] 6.3 Verify vault header at `Application Support/superSecureNotes/vault/vault-header.bin`
