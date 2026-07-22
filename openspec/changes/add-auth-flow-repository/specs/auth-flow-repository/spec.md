## ADDED Requirements

### Requirement: AuthFlow package module boundary

The project SHALL provide a Swift Package `AuthFlow` with two library products: `AuthRepositoryProtocol` (contracts and shared types) and `AuthRepository` (network implementation). `AuthRepositoryProtocol` SHALL depend only on Foundation. `AuthRepository` SHALL depend on `AuthRepositoryProtocol`.

#### Scenario: Package builds with protocol and implementation targets

- **WHEN** the `AuthFlow` package is built
- **THEN** both `AuthRepositoryProtocol` and `AuthRepository` targets compile successfully

#### Scenario: Protocol module has no URLSession dependency

- **WHEN** `AuthRepositoryProtocol` is built
- **THEN** it does not import or reference networking frameworks beyond Foundation

### Requirement: Credential models

The module SHALL define `LoginCredentials` and `RegisterCredentials` as `Sendable`, `Equatable` value types. Each SHALL contain `email: String` and `password: String`.

#### Scenario: Login credentials carry email and password

- **WHEN** a `LoginCredentials` value is created with an email and password
- **THEN** both values are accessible as stored properties

#### Scenario: Register credentials carry email and password

- **WHEN** a `RegisterCredentials` value is created with an email and password
- **THEN** both values are accessible as stored properties

### Requirement: User model

The module SHALL define `User` as a `Sendable`, `Equatable` value type with `id: String`, `email: String`, and `createdAt: Date`.

#### Scenario: User carries identity fields

- **WHEN** a `User` value is created with id, email, and createdAt
- **THEN** all three values are accessible as stored properties

### Requirement: AuthSession model

The module SHALL define `AuthSession` as a `Sendable`, `Equatable` value type with `accessToken: String`, `refreshToken: String`, and `expiresAt: Date`.

#### Scenario: AuthSession carries token fields

- **WHEN** an `AuthSession` value is created with access token, refresh token, and expiry
- **THEN** all three values are accessible as stored properties

### Requirement: AuthRepositoryError

The module SHALL define `AuthRepositoryError` as a `Sendable`, `Equatable` error enum with cases: `invalidCredentials`, `emailAlreadyExists`, `validationError(String)`, `notAuthenticated`, `networkError`, and `serverError(statusCode: Int)`.

#### Scenario: Error cases are equatable

- **WHEN** two `AuthRepositoryError` values of the same case are compared
- **THEN** they are equal

### Requirement: AuthRepository protocol

The module SHALL provide an `AuthRepository` protocol implemented by an `actor` with async methods: `register(_:)`, `login(_:)`, `logout()`, and `refreshSession()`, plus `currentSession` and `currentUser` async properties.

#### Scenario: Initial state has no session or user

- **WHEN** a new `AuthRepository` implementation is created
- **THEN** `currentSession` is `nil` and `currentUser` is `nil`

#### Scenario: Register returns session and stores state

- **WHEN** `register` succeeds with valid credentials
- **THEN** the returned `AuthSession` contains non-empty tokens and `currentSession` and `currentUser` reflect the authenticated state

#### Scenario: Login returns session and stores state

- **WHEN** `login` succeeds with valid credentials
- **THEN** the returned `AuthSession` contains non-empty tokens and `currentSession` and `currentUser` reflect the authenticated state

#### Scenario: Logout clears local state

- **WHEN** `logout` is called on an authenticated repository
- **THEN** `currentSession` is `nil` and `currentUser` is `nil`

#### Scenario: Refresh updates session tokens

- **WHEN** `refreshSession` succeeds while authenticated
- **THEN** `currentSession` is updated with new tokens

#### Scenario: Refresh throws when not authenticated

- **WHEN** `refreshSession` is called with no active session
- **THEN** the call throws `AuthRepositoryError.notAuthenticated`

### Requirement: Register API mapping

`NetworkAuthRepository` SHALL send `POST {baseURL}/auth/register` with JSON body `{ "email": "<email>", "password": "<password>" }`. On `201` response it SHALL parse `user`, `accessToken`, `refreshToken`, and `expiresIn` and return an `AuthSession`.

#### Scenario: Successful register parses response

- **WHEN** the server responds `201` with a valid auth response body
- **THEN** `register` returns an `AuthSession` with `expiresAt` computed from `expiresIn`

#### Scenario: Register maps email conflict

- **WHEN** the server responds `409` with error code `email_already_exists`
- **THEN** `register` throws `AuthRepositoryError.emailAlreadyExists`

#### Scenario: Register maps validation error

- **WHEN** the server responds `400` with error code `validation_error`
- **THEN** `register` throws `AuthRepositoryError.validationError`

#### Scenario: Register rejects empty credentials locally

- **WHEN** `register` is called with an empty email or empty password
- **THEN** the call throws `AuthRepositoryError.validationError` without making a network request

### Requirement: Login API mapping

`NetworkAuthRepository` SHALL send `POST {baseURL}/auth/login` with JSON body `{ "email": "<email>", "password": "<password>" }`. On `200` response it SHALL parse the auth response and return an `AuthSession`.

#### Scenario: Successful login parses response

- **WHEN** the server responds `200` with a valid auth response body
- **THEN** `login` returns an `AuthSession` and stores the user

#### Scenario: Login maps invalid credentials

- **WHEN** the server responds `401` with error code `invalid_credentials`
- **THEN** `login` throws `AuthRepositoryError.invalidCredentials`

#### Scenario: Login rejects empty credentials locally

- **WHEN** `login` is called with an empty email or empty password
- **THEN** the call throws `AuthRepositoryError.validationError` without making a network request

### Requirement: Logout API mapping

`NetworkAuthRepository` SHALL send `POST {baseURL}/auth/logout` with header `Authorization: Bearer <accessToken>`. Local session and user state SHALL be cleared after the request completes, regardless of HTTP status.

#### Scenario: Logout clears state on server success

- **WHEN** the server responds `204` and the repository was authenticated
- **THEN** `currentSession` and `currentUser` are `nil`

#### Scenario: Logout clears state on network failure

- **WHEN** the network request fails and the repository was authenticated
- **THEN** `currentSession` and `currentUser` are still cleared

### Requirement: Refresh API mapping

`NetworkAuthRepository` SHALL send `POST {baseURL}/auth/refresh` with JSON body `{ "refreshToken": "<token>" }`. On `200` response it SHALL update stored session tokens.

#### Scenario: Successful refresh updates tokens

- **WHEN** the server responds `200` with new `accessToken`, `refreshToken`, and `expiresIn`
- **THEN** `refreshSession` returns the updated `AuthSession` and `currentSession` reflects new values

#### Scenario: Refresh maps invalid token

- **WHEN** the server responds `401` with error code `unauthorized`
- **THEN** `refreshSession` throws `AuthRepositoryError.notAuthenticated`

### Requirement: Network errors

When a network request fails due to transport error or returns an unhandled status code, `NetworkAuthRepository` SHALL throw `AuthRepositoryError.networkError` or `AuthRepositoryError.serverError(statusCode:)`.

#### Scenario: Transport failure maps to network error

- **WHEN** the underlying URL session throws a transport error
- **THEN** the repository method throws `AuthRepositoryError.networkError`

#### Scenario: Unhandled status maps to server error

- **WHEN** the server responds with status `500`
- **THEN** the repository method throws `AuthRepositoryError.serverError(statusCode: 500)`

### Requirement: HTTP client is internal

The `AuthRepository` target SHALL NOT expose a public HTTP client protocol or type. All URLSession usage SHALL be internal to the `AuthRepository` target.

#### Scenario: No public HTTP types in AuthRepository product

- **WHEN** the public API of `AuthRepository` is inspected
- **THEN** no HTTP client protocol or URLSession wrapper is publicly exported

### Requirement: In-memory session storage

`NetworkAuthRepository` SHALL store session and user state in actor memory only. No Keychain or file persistence SHALL be used in v1.

#### Scenario: New repository instance has no prior session

- **WHEN** a new `NetworkAuthRepository` is created after another instance was authenticated
- **THEN** the new instance has `currentSession` `nil` and `currentUser` `nil`
