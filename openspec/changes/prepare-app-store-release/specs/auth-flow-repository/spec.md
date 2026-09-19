## ADDED Requirements

### Requirement: AuthRepository deleteAccount

The `AuthRepository` protocol SHALL define `deleteAccount(password: String) async throws`. Implementations SHALL require an active session with a valid access token.

#### Scenario: Delete account requires authentication

- **WHEN** `deleteAccount` is called with no active session
- **THEN** the call throws `AuthRepositoryError.notAuthenticated`

### Requirement: Delete account API mapping

`NetworkAuthRepository` SHALL send `POST {baseURL}/auth/delete-account` with header `Authorization: Bearer <accessToken>` and JSON body `{ "password": "<password>" }`. On `204` or `200` success response it SHALL clear local session and user state.

#### Scenario: Successful delete clears local auth state

- **WHEN** the server responds with a success status for delete-account
- **THEN** `deleteAccount` completes without error and `currentSession` and `currentUser` become `nil`

#### Scenario: Delete maps invalid credentials

- **WHEN** the server responds `401` with error code `invalid_credentials`
- **THEN** `deleteAccount` throws `AuthRepositoryError.invalidCredentials`

#### Scenario: Delete rejects empty password locally

- **WHEN** `deleteAccount` is called with an empty password
- **THEN** the call throws `AuthRepositoryError.validationError` without making a network request

#### Scenario: Delete sends bearer token

- **WHEN** `deleteAccount` is called while authenticated
- **THEN** the outgoing request includes `Authorization: Bearer <current access token>`
