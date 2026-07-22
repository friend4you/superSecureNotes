## ADDED Requirements

### Requirement: VaultRepository package module boundary

The project SHALL provide a Swift Package `VaultRepository` with two library products: `VaultRepositoryProtocol` (contracts and shared types) and `VaultRepository` (network implementation). `VaultRepositoryProtocol` SHALL depend only on Foundation. `VaultRepository` SHALL depend on `VaultRepositoryProtocol`.

#### Scenario: Package builds with protocol and implementation targets

- **WHEN** the `VaultRepository` package is built
- **THEN** both `VaultRepositoryProtocol` and `VaultRepository` targets compile successfully

#### Scenario: Protocol module has no URLSession dependency

- **WHEN** `VaultRepositoryProtocol` is built
- **THEN** it does not import or reference networking frameworks beyond Foundation

### Requirement: AccessTokenProviding protocol

The module SHALL define an `AccessTokenProviding` protocol with a `Sendable` constraint and an async method `accessToken() async throws -> String` that returns a bearer token for authenticated API requests.

#### Scenario: Token provider returns access token

- **WHEN** `accessToken()` is called on a conforming type with a valid session
- **THEN** a non-empty bearer token string is returned

### Requirement: VaultRepositoryError

The module SHALL define `VaultRepositoryError` as a `Sendable`, `Equatable` error enum with cases: `notAuthenticated`, `headerNotFound`, `publicKeyNotFound`, `validationError(String)`, `networkError`, and `serverError(statusCode: Int)`.

#### Scenario: Error cases are equatable

- **WHEN** two `VaultRepositoryError` values of the same case are compared
- **THEN** they are equal

### Requirement: VaultRepository protocol

The module SHALL provide a `VaultRepository` protocol implemented by an `actor` with async methods: `readHeader()`, `writeHeader(_:)`, and `fetchPublicKey(userID:)`. Header methods SHALL use raw `Data` (opaque `vault.meta` bytes). `fetchPublicKey` SHALL accept `userID` as a `String` (UUID matching `User.id` from auth) and return 32 bytes of public key material as `Data`.

#### Scenario: Read header returns vault meta bytes

- **WHEN** `readHeader()` succeeds
- **THEN** the returned `Data` is the stored `vault.meta` blob

#### Scenario: Write header uploads vault meta bytes

- **WHEN** `writeHeader(_:)` succeeds with non-empty header bytes
- **THEN** the header blob is stored on the server for the authenticated user

#### Scenario: Fetch public key returns key bytes

- **WHEN** `fetchPublicKey(userID:)` succeeds
- **THEN** the returned `Data` is exactly 32 bytes of identity public key material

### Requirement: Read header API mapping

`NetworkVaultRepository` SHALL send `GET {baseURL}/vault/header` with header `Authorization: Bearer <accessToken>`. On `200` response it SHALL return the response body as `Data`.

#### Scenario: Successful read returns header bytes

- **WHEN** the server responds `200` with a binary body
- **THEN** `readHeader()` returns the body as `Data`

#### Scenario: Read maps header not found

- **WHEN** the server responds `404` with error code `header_not_found`
- **THEN** `readHeader()` throws `VaultRepositoryError.headerNotFound`

#### Scenario: Read maps unauthorized

- **WHEN** the server responds `401` with error code `unauthorized`
- **THEN** `readHeader()` throws `VaultRepositoryError.notAuthenticated`

### Requirement: Write header API mapping

`NetworkVaultRepository` SHALL send `PUT {baseURL}/vault/header` with header `Authorization: Bearer <accessToken>` and body as raw binary (`Content-Type: application/octet-stream`). On `204` response it SHALL complete successfully.

#### Scenario: Successful write completes

- **WHEN** the server responds `204` to a valid header upload
- **THEN** `writeHeader(_:)` completes without error

#### Scenario: Write maps validation error

- **WHEN** the server responds `400` with error code `validation_error`
- **THEN** `writeHeader(_:)` throws `VaultRepositoryError.validationError`

#### Scenario: Write rejects empty header locally

- **WHEN** `writeHeader(_:)` is called with empty `Data`
- **THEN** the call throws `VaultRepositoryError.validationError` without making a network request

#### Scenario: Write maps unauthorized

- **WHEN** the server responds `401` with error code `unauthorized`
- **THEN** `writeHeader(_:)` throws `VaultRepositoryError.notAuthenticated`

### Requirement: Fetch public key API mapping

`NetworkVaultRepository` SHALL send `GET {baseURL}/users/{userId}/public-key` with header `Authorization: Bearer <accessToken>`. On `200` response it SHALL parse JSON `{ "publicKey": "<base64>", "algorithmId": <number> }` and return the decoded public key as `Data`.

#### Scenario: Successful fetch parses public key

- **WHEN** the server responds `200` with a valid public key JSON body
- **THEN** `fetchPublicKey(userID:)` returns 32 bytes decoded from the `publicKey` field

#### Scenario: Fetch maps public key not found

- **WHEN** the server responds `404` with error code `public_key_not_found`
- **THEN** `fetchPublicKey(userID:)` throws `VaultRepositoryError.publicKeyNotFound`

#### Scenario: Fetch rejects empty user ID locally

- **WHEN** `fetchPublicKey(userID:)` is called with an empty string
- **THEN** the call throws `VaultRepositoryError.validationError` without making a network request

#### Scenario: Fetch maps unauthorized

- **WHEN** the server responds `401` with error code `unauthorized`
- **THEN** `fetchPublicKey(userID:)` throws `VaultRepositoryError.notAuthenticated`

### Requirement: Token provider integration

`NetworkVaultRepository` SHALL obtain the bearer token by calling `accessToken()` on the injected `AccessTokenProviding` dependency before each authenticated request. If `accessToken()` throws, the repository method SHALL propagate the error without making a network request.

#### Scenario: Token provider failure prevents request

- **WHEN** `accessToken()` throws before a vault API call
- **THEN** the repository method throws without sending an HTTP request

### Requirement: Network errors

When a network request fails due to transport error or returns an unhandled status code, `NetworkVaultRepository` SHALL throw `VaultRepositoryError.networkError` or `VaultRepositoryError.serverError(statusCode:)`.

#### Scenario: Transport failure maps to network error

- **WHEN** the underlying URL session throws a transport error
- **THEN** the repository method throws `VaultRepositoryError.networkError`

#### Scenario: Unhandled status maps to server error

- **WHEN** the server responds with status `500`
- **THEN** the repository method throws `VaultRepositoryError.serverError(statusCode: 500)`

### Requirement: HTTP client is internal

The `VaultRepository` target SHALL NOT expose a public HTTP client protocol or type. All URLSession usage SHALL be internal to the `VaultRepository` target.

#### Scenario: No public HTTP types in VaultRepository product

- **WHEN** the public API of `VaultRepository` is inspected
- **THEN** no HTTP client protocol or URLSession wrapper is publicly exported

### Requirement: No crypto parsing in repository

The `VaultRepository` module SHALL NOT parse, validate, or serialize `VaultHeader` structures. Header bytes SHALL be treated as opaque `Data` at the repository boundary.

#### Scenario: Repository returns raw bytes without parsing

- **WHEN** `readHeader()` succeeds
- **THEN** the returned value is the raw response body with no `VaultHeader` parsing performed by the repository
