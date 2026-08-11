## ADDED Requirements

### Requirement: Vault API unauthorized refresh and retry

`VaultAPIClient` SHALL use `AuthorizedRequestPerformer` for all authenticated endpoints. When the server responds `401` with error code `unauthorized`, the client SHALL attempt token refresh and retry the request once before surfacing `VaultRepositoryError.notAuthenticated`.

#### Scenario: Read header retries after token refresh

- **WHEN** `GET /vault/header` returns `401`, refresh succeeds, and the retried request returns `200`
- **THEN** `readHeader` returns the response body

#### Scenario: Write header retries after token refresh

- **WHEN** `PUT /vault/header` returns `401`, refresh succeeds, and the retried request returns `204`
- **THEN** `writeHeader` completes without surfacing `notAuthenticated`

#### Scenario: Fetch public key retries after token refresh

- **WHEN** `GET /users/{userId}/public-key` returns `401`, refresh succeeds, and the retried request returns `200`
- **THEN** `fetchPublicKey` returns the decoded public key bytes

#### Scenario: Vault maps unauthorized after failed refresh

- **WHEN** an authenticated vault request returns `401` and refresh fails with `notAuthenticated`
- **THEN** the vault method throws `VaultRepositoryError.notAuthenticated`
