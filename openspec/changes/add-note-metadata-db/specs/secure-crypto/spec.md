## ADDED Requirements

### Requirement: deriveNotesDatabaseKey helper

The `SecureCrypto` module SHALL provide `deriveNotesDatabaseKey(from udk: SymmetricKey) -> Data` that derives a 32-byte database passphrase using HKDF-SHA256 with info string `"superSecureNotes.notes.db.v1"`. The function SHALL be deterministic for the same UDK input and SHALL NOT return raw UDK bytes.

#### Scenario: Derivation is deterministic

- **WHEN** `deriveNotesDatabaseKey` is called twice with the same UDK
- **THEN** both results are equal

#### Scenario: Derived key differs from raw UDK bytes

- **WHEN** `deriveNotesDatabaseKey` is called with a UDK
- **THEN** the result is not equal to the raw UDK byte representation

### Requirement: Note payload file format

The module SHALL define an on-disk note payload file format consisting of raw encrypted payload bytes only. The format SHALL NOT include magic bytes, version byte, metadata fields, or a wrapped FEK section.

#### Scenario: Payload file contains ciphertext only

- **WHEN** encrypted payload bytes are written to a note payload file and read back
- **THEN** the returned bytes are identical to the original encrypted payload

#### Scenario: Reject empty payload file

- **WHEN** an empty payload file is validated
- **THEN** validation fails with a descriptive error

## REMOVED Requirements

### Requirement: Local note body binary format

**Reason**: Metadata and wrapped FEK moved to `NotesIndexStore`; note files store encrypted payload only.

**Migration**: Remove `assembleLocalNoteBody`, `parseLocalNoteBody`, `LocalNoteBodySections`, and `NoteMetadata.fromLocalNoteBody`. Wipe existing local notes using the old layout.

#### Scenario: Local note body helpers are unavailable

- **WHEN** client code attempts to parse a legacy local note body with SSNT header and metadata
- **THEN** the module does not provide local note body parse helpers

### Requirement: Parse metadata from local note body without decryption

**Reason**: Metadata is no longer stored in note files; listing reads from encrypted index store.

**Migration**: Use `NoteRepository.listNotes()` or read metadata from `StoredNote` returned by `readNote`.

## MODIFIED Requirements

### Requirement: Note file binary format

The module SHALL define a versioned binary `.note` wire format with magic bytes `SSNT`, version byte, a length-prefixed plaintext metadata section, a wrapped FEK blob, and an encrypted payload blob. This wire format is retained for future backend sync and `NetworkNoteRepository` mapping. Local on-disk storage SHALL NOT use this format; local payload files contain encrypted payload bytes only and metadata lives in the encrypted index store.

#### Scenario: Parse note file structure

- **WHEN** a valid `.note` wire blob is parsed
- **THEN** the module returns plaintext metadata, wrapped FEK bytes, and encrypted payload bytes as separate components

#### Scenario: Reject invalid note file

- **WHEN** a blob with incorrect magic bytes or unsupported version is parsed as a wire note file
- **THEN** parsing fails with a descriptive error

### Requirement: Split and reassemble wire-format note blobs

The module SHALL provide helpers to split a wire-format `.note` blob into metadata, wrapped FEK, and encrypted payload (via existing `parseNoteFile`), and to assemble a wire-format `.note` blob from those three components (via existing `assembleNoteFile`). Splitting and reassembly SHALL preserve byte-for-byte equality for valid inputs. These helpers are used by `NetworkNoteRepository` and future sync; local storage does not use wire format on disk.

#### Scenario: Split then reassemble preserves wire blob

- **WHEN** a valid wire-format `.note` blob is split into sections and reassembled
- **THEN** the result is equal to the original blob
