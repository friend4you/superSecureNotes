## ADDED Requirements

### Requirement: Note sync outcome events

The note sync orchestrator SHALL expose a stream or observable source of per-note upload outcomes emitted after each note push attempt during `flushPending()`. Each outcome SHALL identify the note ID and whether upload succeeded (with resulting sync metadata) or failed while leaving the note `pendingSync`.

#### Scenario: Successful upload emits outcome

- **WHEN** a pending note upload completes successfully via PUT or chunked complete
- **THEN** subscribers receive an outcome indicating the note ID and synced state metadata

#### Scenario: Failed upload emits outcome

- **WHEN** a pending note upload fails with a non-conflict error
- **THEN** subscribers receive an outcome indicating the note ID and that upload did not complete

### Requirement: scheduleFlush for non-blocking sync

`NoteSyncing` SHALL provide a non-blocking `scheduleFlush()` (or equivalent) that starts `flushPending()` in a background task without awaiting completion by the caller.

#### Scenario: scheduleFlush does not block caller

- **WHEN** `scheduleFlush()` is called from a ViewModel save path
- **THEN** the caller returns without waiting for network upload to finish

## MODIFIED Requirements

### Requirement: NetworkNoteRepository StoredNote mapping

`NetworkNoteRepository` SHALL map `StoredNote` to wire-format `.note` blobs on write using `assembleNoteFile`, and map wire blobs to `StoredNote` on read using `parseNoteFile` with `syncState: .synced`. It SHALL NOT use `NotesIndexStore`. On upload, it SHALL choose single PUT or chunked upload based on assembled wire blob size relative to `NoteUploadSizeThreshold` as defined in the chunked-note-upload capability.

#### Scenario: Network write assembles wire blob

- **WHEN** `writeNote` or `uploadNote` is called on `NetworkNoteRepository` with a `StoredNote`
- **THEN** upload bytes are derived from a wire-format `.note` blob assembled from the stored note sections

#### Scenario: Network read parses wire blob

- **WHEN** `readNote` succeeds on `NetworkNoteRepository`
- **THEN** the returned `StoredNote` has sections parsed from the wire blob and `syncState` equal to `synced`

#### Scenario: Upload selects transport by size

- **WHEN** `uploadNote` assembles a wire blob whose size exceeds `NoteUploadSizeThreshold`
- **THEN** the network repository uses the chunked upload API instead of single PUT
