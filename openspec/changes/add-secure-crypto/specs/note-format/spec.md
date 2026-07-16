## ADDED Requirements

### Requirement: Note file binary format

The module SHALL define a versioned binary `.note` format with magic bytes `SSNT`, version byte, a length-prefixed plaintext metadata section, a wrapped FEK blob, and an encrypted payload blob.

#### Scenario: Parse note file structure

- **WHEN** a valid `.note` blob is parsed
- **THEN** the module returns plaintext metadata, wrapped FEK bytes, and encrypted payload bytes as separate components

#### Scenario: Reject invalid note file

- **WHEN** a blob with incorrect magic bytes or unsupported version is parsed
- **THEN** parsing fails with a descriptive error

### Requirement: Plaintext note metadata

The plaintext header section of a `.note` file SHALL contain: `note_id` (16-byte UUID), `title` (UTF-8 string), `created_at` (UInt64 epoch seconds), `updated_at` (UInt64 epoch seconds), `attachment_count` (UInt32), and `attachments_total_size` (UInt64 bytes). Tags SHALL NOT be included.

#### Scenario: Parse metadata without decryption

- **WHEN** `NoteMetadata.fromNoteFile(data:)` is called on a valid `.note` blob
- **THEN** the module returns all plaintext metadata fields without requiring UDK or FEK

#### Scenario: Metadata sufficient for list display

- **WHEN** plaintext metadata is parsed
- **THEN** the caller can display title, dates, and attachment summary without unlocking the vault

### Requirement: Per-note FEK wrapping

Each note SHALL have a unique randomly generated FEK. The FEK SHALL be wrapped with the vault UDK using ChaChaPoly and stored in the `.note` file. The module SHALL provide helpers to wrap a new FEK and unwrap an existing wrapped FEK.

#### Scenario: Create wrapped FEK for new note

- **WHEN** a new FEK is generated and wrapped with the vault UDK
- **THEN** the module returns a wrapped FEK blob suitable for inclusion in a `.note` file

#### Scenario: Unwrap FEK for note decryption

- **WHEN** a wrapped FEK blob and the vault UDK are provided
- **THEN** the module returns the original FEK

### Requirement: Encrypted note payload

The encrypted payload SHALL be JSON (UTF-8) encrypted with the note FEK via ChaChaPoly. The JSON schema SHALL contain a `body` field (`Data`) and an `attachments` array. Each attachment SHALL contain `id` (string UUID), `filename` (string), `mime` (string), and `data` (bytes).

#### Scenario: Encrypt note payload

- **WHEN** a `NotePayload` with body and attachments is encrypted with a FEK
- **THEN** the module returns an encrypted payload blob suitable for a `.note` file

#### Scenario: Decrypt note payload

- **WHEN** an encrypted payload blob and the correct FEK are provided
- **THEN** the module returns a `NotePayload` with body and attachments matching the original

#### Scenario: Empty attachments

- **WHEN** a note has no attachments
- **THEN** the encrypted payload contains an empty `attachments` array and `attachment_count` in plaintext metadata is 0

### Requirement: Note file assembly is caller responsibility

The module SHALL provide serialization helpers for individual `.note` sections but SHALL NOT write files to disk. The app layer SHALL assemble complete `.note` blobs from metadata, wrapped FEK, and encrypted payload.

#### Scenario: Serialize note sections

- **WHEN** the caller provides plaintext metadata, wrapped FEK, and encrypted payload
- **THEN** the module returns a complete `.note` byte blob

#### Scenario: Module does not manage filesystem

- **WHEN** note creation or update is performed
- **THEN** the module returns bytes only; no file I/O occurs within SecureCrypto

### Requirement: Plaintext metadata is source of truth

The `.note` file plaintext header SHALL be the authoritative source for note metadata. An app-maintained `index.json` is a cache that MAY be rebuilt by scanning `.note` files via `NoteMetadata.fromNoteFile`.

#### Scenario: Rebuild index from note files

- **WHEN** the app scans all `notes/*.note` files and calls `NoteMetadata.fromNoteFile` on each
- **THEN** sufficient metadata is available to rebuild a listing index without decryption
