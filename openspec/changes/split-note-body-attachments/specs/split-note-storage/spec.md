## ADDED Requirements

### Requirement: Split note storage local layout

The note repository layer SHALL store notes as SSNT `body` bytes plus per-attachment encrypted files, with SQLCipher index rows tracking body and attachment etags for divergence detection against remote manifests.

#### Scenario: Local body etag differs from remote

- **WHEN** local `body_etag` does not match remote list etag for the same note id
- **THEN** sync treats the note as needing body reupload or pull per LWW policy

#### Scenario: Local attachment missing etag row

- **WHEN** manifest lists an attachment id not present locally
- **THEN** hydration or sync download enqueues fetch for that attachment id

### Requirement: NotePayload v2 index in body ciphertext

Encrypted body ciphertext SHALL decode to schema v2 `NotePayload` with attachment index only (id, filename, mime, size). Attachment file bytes SHALL live only in `attachments/{id}` files locally and in remote attachment blobs.

#### Scenario: Detail shows filenames before attachment download

- **WHEN** body is decrypted on a remote/cold open
- **THEN** attachment filenames from the v2 index are available before attachment files are downloaded

### Requirement: Lazy v1 to v2 migration

On read or pre-upload, notes with v1 inline attachment payloads SHALL be rewritten to split storage with regenerated UUID attachment ids and marked `pendingSync`.

#### Scenario: Migration regenerates attachment ids

- **WHEN** a v1 note is migrated
- **THEN** new UUID attachment ids are used in the v2 index and attachment file paths
