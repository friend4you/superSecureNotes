## ADDED Requirements

### Requirement: pendingDelete sync state

The `NoteRepositoryProtocol` module SHALL extend `NoteSyncState` with a `pendingDelete` case in addition to `pendingSync` and `synced`. The value SHALL remain `Sendable` and `Equatable`.

#### Scenario: pendingDelete is equatable

- **WHEN** two `NoteSyncState.pendingDelete` values are compared
- **THEN** they are equal

### Requirement: NoteSummary includes syncState

`NoteSummary` SHALL include a `syncState: NoteSyncState` field alongside `noteID`, `title`, and `updatedAt`.

#### Scenario: List summaries expose sync state

- **WHEN** `listNotes()` returns summaries for stored notes
- **THEN** each `NoteSummary` includes the note's current `syncState`

### Requirement: Notes index stores etag

`NotesIndexStore` SHALL persist an optional `etag` string per note row for sync conditional requests.

#### Scenario: Etag roundtrip

- **WHEN** a note index row is upserted with an etag and fetched again
- **THEN** the stored etag matches the written value

### Requirement: Network note PUT accepts 200 upload response

`NoteAPIClient` / `NetworkNoteRepository` SHALL treat HTTP `200` on `PUT /notes/{noteId}` as success and SHALL parse JSON body fields `syncState`, `updatedAt`, and `etag`. It SHALL NOT require HTTP `204` for successful note upload.

#### Scenario: Write succeeds on 200 with etag body

- **WHEN** the server responds `200` with a note upload JSON body including `etag`
- **THEN** the network write completes successfully and exposes the returned etag to the caller

#### Scenario: Write still maps unauthorized

- **WHEN** the server responds `401` on note PUT
- **THEN** `NoteRepositoryError.notAuthenticated` is thrown

### Requirement: Local list excludes pendingDelete notes

`LocalNoteRepository.listNotes()` SHALL omit notes whose `syncState` is `pendingDelete` (or equivalent outbox-only deletes that have already removed index visibility).

#### Scenario: Pending delete not listed

- **WHEN** a note is marked for remote delete and removed from visible local storage
- **THEN** `listNotes()` does not include that note ID

## MODIFIED Requirements

### Requirement: NoteSyncState enum

The `NoteRepositoryProtocol` module SHALL define a `NoteSyncState` enum that is `Sendable` and `Equatable` with cases `pendingSync`, `synced`, and `pendingDelete`.

#### Scenario: NoteSyncState cases are equatable

- **WHEN** two `NoteSyncState.pendingSync` values are compared
- **THEN** they are equal

#### Scenario: pendingDelete differs from synced

- **WHEN** `NoteSyncState.pendingDelete` is compared to `NoteSyncState.synced`
- **THEN** they are not equal

### Requirement: NotesIndexStore schema

`NotesIndexStore` SHALL persist note index rows with columns: `note_id`, `title`, `created_at`, `updated_at`, `attachment_count`, `attachments_total_size`, `wrapped_fek`, `sync_state`, and optional `etag`. The `sync_state` column SHALL allow `pendingSync`, `synced`, and `pendingDelete`.

#### Scenario: Row roundtrip preserves fields

- **WHEN** a note index row is upserted and fetched by `note_id`
- **THEN** all column values match the written row including etag when present

#### Scenario: sync_state accepts pendingDelete

- **WHEN** a row is upserted with `sync_state` equal to `pendingDelete`
- **THEN** a subsequent fetch returns `pendingDelete`

### Requirement: LocalNoteRepository list notes from index store

`LocalNoteRepository.listNotes()` SHALL query `NotesIndexStore` and return `NoteSummary` entries including `syncState`. It SHALL NOT scan payload directories for metadata. It SHALL exclude notes that are pending remote delete and no longer visible.

#### Scenario: List notes from index store

- **WHEN** one or more visible notes exist in the index store
- **THEN** `listNotes()` returns `NoteSummary` values with `noteID`, `title`, `updatedAt`, and `syncState` from index rows

#### Scenario: List returns empty when no notes

- **WHEN** the index store contains no visible note rows
- **THEN** `listNotes()` returns an empty array
