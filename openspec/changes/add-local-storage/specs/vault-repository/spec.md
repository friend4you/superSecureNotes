## ADDED Requirements

### Requirement: LocalVaultRepository actor

The `VaultRepository` target SHALL provide a `LocalVaultRepository` actor conforming to `VaultRepository`. It SHALL persist the vault header at `Application Support/superSecureNotes/vault/vault-header.bin`. It SHALL exclude the vault storage directory from iCloud backup.

#### Scenario: Write and read header roundtrip

- **WHEN** `writeHeader(headerData)` is called with non-empty `Data`
- **THEN** a subsequent `readHeader()` returns equal `Data`

#### Scenario: Read missing header throws headerNotFound

- **WHEN** `readHeader()` is called and no header file exists
- **THEN** `VaultRepositoryError.headerNotFound` is thrown

#### Scenario: Header survives new repository instance

- **WHEN** a header is written and a new `LocalVaultRepository` instance reads the header
- **THEN** the returned data matches the written header

#### Scenario: Fetch public key returns placeholder

- **WHEN** `fetchPublicKey(userID:)` is called on `LocalVaultRepository`
- **THEN** 32 zero bytes are returned until a backend public-key directory exists

### Requirement: LocalVaultRepository atomic header write

`LocalVaultRepository` SHALL write the header file atomically (e.g. write to temporary file then replace).

#### Scenario: Atomic header write

- **WHEN** `writeHeader` is called twice in succession
- **THEN** `readHeader` returns the latest header bytes without partial content

## MODIFIED Requirements

### Requirement: VaultRepository protocol

The module SHALL provide a `VaultRepository` protocol implemented by an `actor` with async methods: `readHeader()`, `writeHeader(_:)`, and `fetchPublicKey(userID:)`. Header methods SHALL use raw `Data` (opaque `vault.meta` bytes). `fetchPublicKey` SHALL accept `userID` as a `String` (UUID matching `User.id` from auth) and return 32 bytes of public key material as `Data`. `LocalVaultRepository` and `NetworkVaultRepository` SHALL both conform to this protocol.

#### Scenario: Read header returns vault meta bytes

- **WHEN** `readHeader()` succeeds
- **THEN** the returned `Data` is the stored `vault.meta` blob

#### Scenario: Write header stores vault meta bytes

- **WHEN** `writeHeader(_:)` succeeds with non-empty header bytes
- **THEN** the header blob is persisted for subsequent `readHeader()`

#### Scenario: Fetch public key returns key bytes

- **WHEN** `fetchPublicKey(userID:)` succeeds
- **THEN** the returned `Data` is exactly 32 bytes of identity public key material
