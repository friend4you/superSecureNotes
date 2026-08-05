## ADDED Requirements

### Requirement: Fetch public key by email

`VaultRepository` SHALL expose `fetchPublicKey(email: String) async throws -> Data` that sends `GET /v1/users/public-key?email={email}` with Bearer authorization and returns the decoded 32-byte public key from JSON `{ "publicKey": "<base64>", "algorithmId": 1 }`. Empty email SHALL be rejected locally with `VaultRepositoryError.validationError`.

#### Scenario: Successful lookup by email

- **WHEN** `fetchPublicKey(email:)` is called with a registered user's email
- **THEN** 32 bytes of public key material are returned

#### Scenario: Reject empty email

- **WHEN** `fetchPublicKey(email:)` is called with an empty string
- **THEN** `VaultRepositoryError.validationError` is thrown without a network request

#### Scenario: Map public key not found

- **WHEN** the API returns `404` with error `public_key_not_found`
- **THEN** `VaultRepositoryError.publicKeyNotFound` is thrown

### Requirement: LocalVaultRepository email public key stub

`LocalVaultRepository.fetchPublicKey(email:)` SHALL return 32 zero bytes for any non-empty email until a backend directory exists.

#### Scenario: Stub returns placeholder key

- **WHEN** `LocalVaultRepository.fetchPublicKey(email: "user@example.com")` is called
- **THEN** 32 zero bytes are returned
