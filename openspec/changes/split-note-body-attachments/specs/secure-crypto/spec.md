## ADDED Requirements

### Requirement: NotePayload schema version 2

The `SecureCrypto` module SHALL define `NotePayload` schema version 2 where the encrypted JSON contains `schemaVersion: 2`, a `body` field (`Data`), and an `attachments` array of index entries with fields `id` (UUID string), `filename`, `mime`, and `size` (byte count). Schema v2 entries SHALL NOT include inline attachment `data`.

#### Scenario: Encrypt and decrypt v2 payload roundtrip

- **WHEN** a v2 `NotePayload` with body text and attachment index entries is encrypted with a FEK and decrypted
- **THEN** the decrypted payload matches the original body and attachment index (without file bytes)

#### Scenario: v2 attachment index excludes data

- **WHEN** a v2 `NotePayload` is encoded to JSON before encryption
- **THEN** no attachment entry contains a `data` field

### Requirement: NotePayload schema version 1 compatibility

The module SHALL support decrypting schema v1 payloads where attachment entries include inline `data` bytes and `schemaVersion` is absent or equal to 1.

#### Scenario: Decrypt v1 inline attachment payload

- **WHEN** a v1 encrypted payload with inline attachment `data` is decrypted
- **THEN** the module returns body and attachments including file bytes

### Requirement: Attachment file encryption

The module SHALL provide helpers to encrypt raw attachment file bytes and decrypt attachment ciphertext using the note FEK (`encrypt(_:key:)` / `decrypt(_:key:)`). Attachment blobs SHALL NOT include an additional envelope beyond ciphertext.

#### Scenario: Attachment encrypt decrypt roundtrip

- **WHEN** raw attachment bytes are encrypted with a note FEK and decrypted with the same FEK
- **THEN** the result equals the original raw bytes

### Requirement: Legacy payload migration helper

The module SHALL provide a helper that converts a decrypted v1 `NotePayload` (inline attachment data) to v2 index entries plus a map of attachment id to raw file bytes, regenerating attachment ids as new UUID strings.

#### Scenario: Migrate v1 to v2 regenerates UUIDs

- **WHEN** a v1 payload with string attachment ids and inline data is migrated
- **THEN** v2 index entries use new UUID ids, include filename/mime/size, and raw bytes are returned keyed by new id
