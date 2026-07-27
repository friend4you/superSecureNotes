## 1. Package Structure

- [x] 1.1 Create `Packages/NoteRepository/Package.swift` with `NoteRepositoryProtocol` and `NoteRepository` targets/products, `VaultRepositoryProtocol` dependency on implementation target, and test targets (platforms: iOS 17+, macOS 13+)
- [x] 1.2 Scaffold `Sources/NoteRepositoryProtocol/` and `Sources/NoteRepository/` module entry points
- [x] 1.3 Add `NoteRepository` package dependency to Xcode project

## 2. NoteRepositoryError

- [x] 2.1 Write failing tests: `NoteRepositoryError` cases are `Equatable` and `Sendable` (`NoteRepositoryProtocolTests/NoteRepositoryErrorTests.swift`)
- [x] 2.2 Add `NoteRepositoryError` to `NoteRepositoryProtocol`; make tests pass

## 3. NoteSummary Model

- [x] 3.1 Write failing tests: `NoteSummary` is `Equatable` and `Sendable`; two values with same fields are equal (`NoteRepositoryProtocolTests/NoteSummaryTests.swift`)
- [x] 3.2 Add `NoteSummary` to `NoteRepositoryProtocol/Models/NoteSummary.swift`; make tests pass

## 4. NoteRepository Protocol

- [x] 4.1 Write failing tests: `NoteRepository` protocol compiles with `listNotes`, `readNote`, `writeNote`, and `deleteNote`; mock actor type satisfies contract (`NoteRepositoryProtocolTests/NoteRepositoryTests.swift`)
- [x] 4.2 Add `NoteRepository` protocol definition to `NoteRepositoryProtocol/NoteRepository.swift`

## 5. Test Infrastructure — URLProtocol Stub

- [x] 5.1 Write `URLProtocolStub` test helper and fixture builders for note API responses (`NoteRepositoryTests/Support/URLProtocolStub.swift`, `NoteFixtures.swift`)
- [x] 5.2 Verify stub can intercept requests and return configured responses in a smoke test

## 6. Internal API Client — List Notes

- [x] 6.1 Write failing tests: internal `NoteAPIClient` sends `GET /notes` with Bearer token; parses JSON array on `200`; returns empty array; maps `401 unauthorized` (`NoteRepositoryTests/NoteAPIClientListNotesTests.swift`)
- [x] 6.2 Implement `listNotes` in internal `NoteAPIClient` and `NoteResponseDTO`; make tests pass

## 7. Internal API Client — Read Note

- [x] 7.1 Write failing tests: internal `NoteAPIClient` sends `GET /notes/{noteId}` with Bearer token; returns body on `200`; maps `404 note_not_found` and `401 unauthorized` (`NoteRepositoryTests/NoteAPIClientReadNoteTests.swift`)
- [x] 7.2 Implement `readNote` in `NoteAPIClient`; make tests pass

## 8. Internal API Client — Write Note

- [x] 8.1 Write failing tests: internal `NoteAPIClient` sends `PUT /notes/{noteId}` with Bearer token and octet-stream body; succeeds on `204`; maps `400 validation_error` and `401 unauthorized` (`NoteRepositoryTests/NoteAPIClientWriteNoteTests.swift`)
- [x] 8.2 Implement `writeNote` in `NoteAPIClient`; make tests pass

## 9. Internal API Client — Delete Note

- [x] 9.1 Write failing tests: internal `NoteAPIClient` sends `DELETE /notes/{noteId}` with Bearer token; succeeds on `204`; maps `404 note_not_found` and `401 unauthorized` (`NoteRepositoryTests/NoteAPIClientDeleteNoteTests.swift`)
- [x] 9.2 Implement `deleteNote` in `NoteAPIClient`; make tests pass

## 10. NetworkNoteRepository — List Notes

- [x] 10.1 Write failing tests: `listNotes` returns summaries on `200`; returns empty array; propagates token provider failure without network call (`NoteRepositoryTests/NetworkNoteRepositoryListNotesTests.swift`)
- [x] 10.2 Implement `listNotes` in `actor NetworkNoteRepository`; make tests pass

## 11. NetworkNoteRepository — Read Note

- [x] 11.1 Write failing tests: `readNote` returns body on `200`; maps `noteNotFound`; propagates token provider failure (`NoteRepositoryTests/NetworkNoteRepositoryReadNoteTests.swift`)
- [x] 11.2 Implement `readNote` in `NetworkNoteRepository`; make tests pass

## 12. NetworkNoteRepository — Write Note

- [x] 12.1 Write failing tests: `writeNote` succeeds on `204`; rejects empty `Data` locally; maps `validationError`; propagates token provider failure (`NoteRepositoryTests/NetworkNoteRepositoryWriteNoteTests.swift`)
- [x] 12.2 Implement `writeNote` in `NetworkNoteRepository`; make tests pass

## 13. NetworkNoteRepository — Delete Note

- [x] 13.1 Write failing tests: `deleteNote` succeeds on `204`; maps `noteNotFound`; propagates token provider failure (`NoteRepositoryTests/NetworkNoteRepositoryDeleteNoteTests.swift`)
- [x] 13.2 Implement `deleteNote` in `NetworkNoteRepository`; make tests pass

## 14. NetworkNoteRepository — Error Mapping

- [x] 14.1 Write failing tests: transport failure throws `networkError`; unhandled status (e.g. `500`) throws `serverError(statusCode:)` (`NoteRepositoryTests/NetworkNoteRepositoryErrorTests.swift`)
- [x] 14.2 Implement error mapping in `NoteAPIClient` / `NetworkNoteRepository`; make tests pass

## 15. Module Integration

- [ ] 15.1 Add `@_exported import NoteRepositoryProtocol` to `NoteRepository` module entry point
- [ ] 15.2 Verify all `NoteRepositoryProtocolTests` and `NoteRepositoryTests` pass
- [ ] 15.3 Add `Packages/NoteRepository/README.md` with module dependency diagram, REST API summary, and import guidance
