## 1. Package Structure

- [ ] 1.1 Create `Packages/VaultRepository/Package.swift` with `VaultRepositoryProtocol` and `VaultRepository` targets/products and test targets (platforms: iOS 17+, macOS 13+)
- [ ] 1.2 Scaffold `Sources/VaultRepositoryProtocol/` and `Sources/VaultRepository/` module entry points
- [ ] 1.3 Add `VaultRepository` package dependency to Xcode project

## 2. VaultRepositoryError

- [ ] 2.1 Write failing tests: `VaultRepositoryError` cases are `Equatable` and `Sendable` (`VaultRepositoryProtocolTests/VaultRepositoryErrorTests.swift`)
- [ ] 2.2 Add `VaultRepositoryError` to `VaultRepositoryProtocol`; make tests pass

## 3. AccessTokenProviding Protocol

- [ ] 3.1 Write failing tests: `AccessTokenProviding` protocol compiles; mock type satisfies contract (`VaultRepositoryProtocolTests/AccessTokenProvidingTests.swift`)
- [ ] 3.2 Add `AccessTokenProviding` protocol to `VaultRepositoryProtocol/AccessTokenProviding.swift`

## 4. VaultRepository Protocol

- [ ] 4.1 Write failing tests: `VaultRepository` protocol compiles with `readHeader`, `writeHeader`, and `fetchPublicKey`; mock actor type satisfies contract (`VaultRepositoryProtocolTests/VaultRepositoryTests.swift`)
- [ ] 4.2 Add `VaultRepository` protocol definition to `VaultRepositoryProtocol/VaultRepository.swift`

## 5. Test Infrastructure — URLProtocol Stub

- [ ] 5.1 Write `URLProtocolStub` test helper and fixture builders for vault API responses (`VaultRepositoryTests/Support/URLProtocolStub.swift`, `VaultFixtures.swift`)
- [ ] 5.2 Verify stub can intercept requests and return configured responses in a smoke test

## 6. Internal API Client — Read Header

- [ ] 6.1 Write failing tests: internal `VaultAPIClient` sends `GET /vault/header` with Bearer token; returns body on `200`; maps `404 header_not_found` and `401 unauthorized` (`VaultRepositoryTests/VaultAPIClientReadHeaderTests.swift`)
- [ ] 6.2 Implement `readHeader` in internal `VaultAPIClient`; make tests pass

## 7. Internal API Client — Write Header

- [ ] 7.1 Write failing tests: internal `VaultAPIClient` sends `PUT /vault/header` with Bearer token and octet-stream body; succeeds on `204`; maps `400 validation_error` and `401 unauthorized` (`VaultRepositoryTests/VaultAPIClientWriteHeaderTests.swift`)
- [ ] 7.2 Implement `writeHeader` in `VaultAPIClient`; make tests pass

## 8. Internal API Client — Fetch Public Key

- [ ] 8.1 Write failing tests: internal `VaultAPIClient` sends `GET /users/{userId}/public-key` with Bearer token; parses JSON `publicKey` base64 on `200`; maps `404 public_key_not_found` and `401 unauthorized` (`VaultRepositoryTests/VaultAPIClientFetchPublicKeyTests.swift`)
- [ ] 8.2 Implement `fetchPublicKey` and `VaultResponseDTO` in `VaultRepository/Internal/`; make tests pass

## 9. NetworkVaultRepository — Read Header

- [ ] 9.1 Write failing tests: `readHeader` returns body on `200`; maps `headerNotFound`; propagates token provider failure without network call (`VaultRepositoryTests/NetworkVaultRepositoryReadHeaderTests.swift`)
- [ ] 9.2 Implement `readHeader` in `actor NetworkVaultRepository`; make tests pass

## 10. NetworkVaultRepository — Write Header

- [ ] 10.1 Write failing tests: `writeHeader` succeeds on `204`; rejects empty `Data` locally; maps `validationError`; propagates token provider failure (`VaultRepositoryTests/NetworkVaultRepositoryWriteHeaderTests.swift`)
- [ ] 10.2 Implement `writeHeader` in `NetworkVaultRepository`; make tests pass

## 11. NetworkVaultRepository — Fetch Public Key

- [ ] 11.1 Write failing tests: `fetchPublicKey` returns 32-byte `Data` on `200`; maps `publicKeyNotFound`; rejects empty `userID` locally; propagates token provider failure (`VaultRepositoryTests/NetworkVaultRepositoryFetchPublicKeyTests.swift`)
- [ ] 11.2 Implement `fetchPublicKey` in `NetworkVaultRepository`; make tests pass

## 12. NetworkVaultRepository — Error Mapping

- [ ] 12.1 Write failing tests: transport failure throws `networkError`; unhandled status (e.g. `500`) throws `serverError(statusCode:)` (`VaultRepositoryTests/NetworkVaultRepositoryErrorTests.swift`)
- [ ] 12.2 Implement error mapping in `VaultAPIClient` / `NetworkVaultRepository`; make tests pass

## 13. Module Integration

- [ ] 13.1 Add `@_exported import VaultRepositoryProtocol` to `VaultRepository` module entry point
- [ ] 13.2 Verify all `VaultRepositoryProtocolTests` and `VaultRepositoryTests` pass
- [ ] 13.3 Add `Packages/VaultRepository/README.md` with module dependency diagram, REST API summary, and import guidance
