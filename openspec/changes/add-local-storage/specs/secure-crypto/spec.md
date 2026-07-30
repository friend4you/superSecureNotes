## ADDED Requirements

### Requirement: Local note body binary format

The module SHALL define a local on-disk note body format with magic bytes `SSNT`, version byte `1`, plaintext metadata fields (same as wire-format `.note`), and a length-prefixed encrypted payload blob. The local format SHALL NOT include a wrapped FEK section.

#### Scenario: Parse local note body structure

- **WHEN** a valid local note body blob is parsed
- **THEN** the module returns plaintext metadata and encrypted payload bytes as separate components

#### Scenario: Reject invalid local note body

- **WHEN** a blob with incorrect magic bytes or unsupported version is parsed as a local note body
- **THEN** parsing fails with a descriptive error

#### Scenario: Assemble local note body roundtrip

- **WHEN** metadata and encrypted payload are assembled into a local note body and parsed back
- **THEN** the returned metadata and encrypted payload match the originals

### Requirement: Split and reassemble wire-format note blobs

The module SHALL provide helpers to split a wire-format `.note` blob into metadata, wrapped FEK, and encrypted payload (via existing `parseNoteFile`), and to assemble a wire-format `.note` blob from those three components (via existing `assembleNoteFile`). Splitting and reassembly SHALL preserve byte-for-byte equality for valid inputs.

#### Scenario: Split then reassemble preserves wire blob

- **WHEN** a valid wire-format `.note` blob is split into sections and reassembled
- **THEN** the result is equal to the original blob

#### Scenario: Parse metadata from local note body without decryption

- **WHEN** metadata helpers are applied to a valid local note body blob
- **THEN** all plaintext metadata fields are returned without requiring UDK or FEK

## MODIFIED Requirements

### Requirement: Note file binary format

The module SHALL define a versioned binary `.note` wire format with magic bytes `SSNT`, version byte, a length-prefixed plaintext metadata section, a wrapped FEK blob, and an encrypted payload blob. This wire format is used at the `NoteRepository` API boundary and for future backend sync. Local on-disk storage MAY use the separate local note body format without a wrapped FEK section.

#### Scenario: Parse note file structure

- **WHEN** a valid `.note` blob is parsed
- **THEN** the module returns plaintext metadata, wrapped FEK bytes, and encrypted payload bytes as separate components

#### Scenario: Reject invalid note file

- **WHEN** a blob with incorrect magic bytes or unsupported version is parsed
- **THEN** parsing fails with a descriptive error
