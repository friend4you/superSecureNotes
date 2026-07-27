## ADDED Requirements

### Requirement: NoteRepository package module boundary

The project SHALL provide a Swift Package `NoteRepository` with two library products: `NoteRepositoryProtocol` (contracts and shared types) and `NoteRepository` (network implementation). `NoteRepositoryProtocol` SHALL depend only on Foundation. `NoteRepository` SHALL depend on `NoteRepositoryProtocol` and `VaultRepositoryProtocol` (for `AccessTokenProviding`).

#### Scenario: Package builds with protocol and implementation targets

- **WHEN** the `NoteRepository` package is built
- **THEN** both `NoteRepositoryProtocol` and `NoteRepository` targets compile successfully

#### Scenario: Protocol module has no URLSession dependency

- **WHEN** `NoteRepositoryProtocol` is built
- **THEN** it does not import or reference networking frameworks beyond Foundation

### Requirement: NoteSummary model

The module SHALL define a `NoteSummary` struct that is `Equatable` and `Sendable` with fields: `noteID: UUID`, `title: String`, and `updatedAt: UInt64` (epoch seconds).

#### Scenario: NoteSummary is equatable

- **WHEN** two `NoteSummary` values with the same field values are compared
- **THEN** they are equal

### Requirement: NoteRepositoryError

The module SHALL define `NoteRepositoryError` as a `Sendable`, `Equatable` error enum with cases: `notAuthenticated`, `noteNotFound`, `validationError(String)`, `networkError`, and `serverError(statusCode: Int)`.

#### Scenario: Error cases are equatable

- **WHEN** two `NoteRepositoryError` values of the same case are compared
- **THEN** they are equal

### Requirement: NoteRepository protocol

The module SHALL provide a `NoteRepository` protocol implemented by an `actor` with async methods: `listNotes()`, `readNote(noteID:)`, `writeNote(noteID:data:)`, and `deleteNote(noteID:)`. Read and write methods for note content SHALL use raw `Data` (opaque `.note` bytes). `listNotes()` SHALL return `[NoteSummary]`.

#### Scenario: List notes returns summaries

- **WHEN** `listNotes()` succeeds
- **THEN** the returned array contains `NoteSummary` values with note ID, title, and updated timestamp

#### Scenario: Read note returns note blob bytes

- **WHEN** `readNote(noteID:)` succeeds
- **THEN** the returned `Data` is the stored `.note` blob

#### Scenario: Write note uploads note blob bytes

- **WHEN** `writeNote(noteID:data:)` succeeds with non-empty note bytes
- **THEN** the note blob is stored on the server for the authenticated user

#### Scenario: Delete note removes note from server

- **WHEN** `deleteNote(noteID:)` succeeds
- **THEN** the note is no longer retrievable via `readNote(noteID:)`

### Requirement: List notes API mapping

`NetworkNoteRepository` SHALL send `GET {baseURL}/notes` with header `Authorization: Bearer <accessToken>`. On `200` response it SHALL parse a JSON array of objects with `noteId`, `title`, and `updatedAt` fields into `[NoteSummary]`.

#### Scenario: Successful list returns summaries

- **WHEN** the server responds `200` with a valid JSON array of note summaries
- **THEN** `listNotes()` returns the parsed `[NoteSummary]`

#### Scenario: Successful list returns empty array

- **WHEN** the server responds `200` with an empty JSON array
- **THEN** `listNotes()` returns an empty array

#### Scenario: List maps unauthorized

- **WHEN** the server responds `401` with error code `unauthorized`
- **THEN** `listNotes()` throws `NoteRepositoryError.notAuthenticated`

### Requirement: Read note API mapping

`NetworkNoteRepository` SHALL send `GET {baseURL}/notes/{noteId}` with header `Authorization: Bearer <accessToken>`. On `200` response it SHALL return the response body as `Data`.

#### Scenario: Successful read returns note bytes

- **WHEN** the server responds `200` with a binary body
- **THEN** `readNote(noteID:)` returns the body as `Data`

#### Scenario: Read maps note not found

- **WHEN** the server responds `404` with error code `note_not_found`
- **THEN** `readNote(noteID:)` throws `NoteRepositoryError.noteNotFound`

#### Scenario: Read maps unauthorized

- **WHEN** the server responds `401` with error code `unauthorized`
- **THEN** `readNote(noteID:)` throws `NoteRepositoryError.notAuthenticated`

### Requirement: Write note API mapping

`NetworkNoteRepository` SHALL send `PUT {baseURL}/notes/{noteId}` with header `Authorization: Bearer <accessToken>` and body as raw binary (`Content-Type: application/octet-stream`). On `204` response it SHALL complete successfully.

#### Scenario: Successful write completes

- **WHEN** the server responds `204` to a valid note upload
- **THEN** `writeNote(noteID:data:)` completes without error

#### Scenario: Write maps validation error

- **WHEN** the server responds `400` with error code `validation_error`
- **THEN** `writeNote(noteID:data:)` throws `NoteRepositoryError.validationError`

#### Scenario: Write rejects empty data locally

- **WHEN** `writeNote(noteID:data:)` is called with empty `Data`
- **THEN** the call throws `NoteRepositoryError.validationError` without making a network request

#### Scenario: Write maps unauthorized

- **WHEN** the server responds `401` with error code `unauthorized`
- **THEN** `writeNote(noteID:data:)` throws `NoteRepositoryError.notAuthenticated`

### Requirement: Delete note API mapping

`NetworkNoteRepository` SHALL send `DELETE {baseURL}/notes/{noteId}` with header `Authorization: Bearer <accessToken>`. On `204` response it SHALL complete successfully.

#### Scenario: Successful delete completes

- **WHEN** the server responds `204` to a delete request
- **THEN** `deleteNote(noteID:)` completes without error

#### Scenario: Delete maps note not found

- **WHEN** the server responds `404` with error code `note_not_found`
- **THEN** `deleteNote(noteID:)` throws `NoteRepositoryError.noteNotFound`

#### Scenario: Delete maps unauthorized

- **WHEN** the server responds `401` with error code `unauthorized`
- **THEN** `deleteNote(noteID:)` throws `NoteRepositoryError.notAuthenticated`

### Requirement: Token provider integration

`NetworkNoteRepository` SHALL obtain the bearer token by calling `accessToken()` on the injected `AccessTokenProviding` dependency before each authenticated request. If `accessToken()` throws, the repository method SHALL propagate the error without making a network request.

#### Scenario: Token provider failure prevents request

- **WHEN** `accessToken()` throws before a note API call
- **THEN** the repository method throws without sending an HTTP request

### Requirement: Network errors

When a network request fails due to transport error or returns an unhandled status code, `NetworkNoteRepository` SHALL throw `NoteRepositoryError.networkError` or `NoteRepositoryError.serverError(statusCode:)`.

#### Scenario: Transport failure maps to network error

- **WHEN** the underlying URL session throws a transport error
- **THEN** the repository method throws `NoteRepositoryError.networkError`

#### Scenario: Unhandled status maps to server error

- **WHEN** the server responds with status `500`
- **THEN** the repository method throws `NoteRepositoryError.serverError(statusCode: 500)`

### Requirement: HTTP client is internal

The `NoteRepository` target SHALL NOT expose a public HTTP client protocol or type. All URLSession usage SHALL be internal to the `NoteRepository` target.

#### Scenario: No public HTTP types in NoteRepository product

- **WHEN** the public API of `NoteRepository` is inspected
- **THEN** no HTTP client protocol or URLSession wrapper is publicly exported

### Requirement: No crypto parsing in repository

The `NoteRepository` module SHALL NOT parse, validate, or serialize `NoteMetadata` or `NoteFileSections` structures. Note blob bytes SHALL be treated as opaque `Data` at the repository boundary.

#### Scenario: Repository returns raw bytes without parsing

- **WHEN** `readNote(noteID:)` succeeds
- **THEN** the returned value is the raw response body with no `NoteMetadata` parsing performed by the repository
