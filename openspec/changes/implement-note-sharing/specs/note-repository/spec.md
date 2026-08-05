## ADDED Requirements

### Requirement: SharedNoteSummary model

`NoteRepositoryProtocol` SHALL define a `SharedNoteSummary` struct that is `Sendable` and `Equatable` with fields: `noteID: UUID`, `title: String`, `updatedAt: UInt64`, `etag: String`, `ownerEmail: String`, `ownerID: UUID`, and `sharedAt: Date`.

#### Scenario: SharedNoteSummary is equatable

- **WHEN** two `SharedNoteSummary` values have identical fields
- **THEN** they are equal

### Requirement: SharedNote model

`NoteRepositoryProtocol` SHALL define a `SharedNote` struct that is `Sendable` and `Equatable` with fields: `noteID: UUID`, `metadata: NoteMetadata`, `recipientWrappedFEK: Data`, and `encryptedPayload: Data`.

#### Scenario: SharedNote carries download payload

- **WHEN** a `SharedNote` is constructed from a shared download response
- **THEN** it includes metadata, recipient-wrapped FEK bytes, and encrypted payload bytes

### Requirement: NoteRepository sharing methods

`NoteRepository` SHALL expose async methods: `shareNote(noteID:recipientEmail:wrappedFEK:)`, `listSharedNotes()`, and `readSharedNote(noteID:)`. `shareNote` SHALL POST `{ "recipientEmail": "<email>", "wrappedFek": "<base64>" }` to `/v1/notes/{note_id}/share`. `listSharedNotes` SHALL GET `/v1/notes/shared`. `readSharedNote` SHALL GET `/v1/notes/shared/{note_id}` and parse the note blob.

#### Scenario: Share note posts grant

- **WHEN** `shareNote(noteID:recipientEmail:wrappedFEK:)` succeeds
- **THEN** a share grant is created on the server for that recipient

#### Scenario: List shared notes returns summaries

- **WHEN** `listSharedNotes()` succeeds
- **THEN** an array of `SharedNoteSummary` is returned with owner email and shared timestamp

#### Scenario: Read shared note returns decrypted-ready blob

- **WHEN** `readSharedNote(noteID:)` succeeds
- **THEN** a `SharedNote` with metadata, recipient-wrapped FEK, and encrypted payload is returned

### Requirement: LocalNoteRepository sharing stubs

`LocalNoteRepository` SHALL implement sharing methods as stubs: `listSharedNotes()` returns `[]`; `shareNote` and `readSharedNote` throw `NoteRepositoryError.notSupported`.

#### Scenario: Local list returns empty

- **WHEN** `LocalNoteRepository.listSharedNotes()` is called
- **THEN** an empty array is returned
