## 1. Package Structure

- [ ] 1.1 Create `Packages/AuthFlow/Package.swift` with `AuthRepositoryProtocol` and `AuthRepository` targets/products and test targets (platforms: iOS 17+, macOS 13+)
- [ ] 1.2 Scaffold `Sources/AuthRepositoryProtocol/` and `Sources/AuthRepository/` module entry points
- [ ] 1.3 Add `AuthFlow` package dependency to Xcode project

## 2. Credential Models

- [ ] 2.1 Write failing tests: `LoginCredentials` and `RegisterCredentials` hold email and password; conform to `Sendable` and `Equatable` (`AuthRepositoryProtocolTests/CredentialsTests.swift`)
- [ ] 2.2 Add `LoginCredentials` and `RegisterCredentials` to `AuthRepositoryProtocol`; make tests pass

## 3. User and AuthSession Models

- [ ] 3.1 Write failing tests: `User` holds `id`, `email`, `createdAt`; `AuthSession` holds `accessToken`, `refreshToken`, `expiresAt`; both `Sendable` and `Equatable` (`AuthRepositoryProtocolTests/ModelsTests.swift`)
- [ ] 3.2 Add `User` and `AuthSession` to `AuthRepositoryProtocol`; make tests pass

## 4. AuthRepositoryError

- [ ] 4.1 Write failing tests: `AuthRepositoryError` cases are `Equatable` and `Sendable` (`AuthRepositoryProtocolTests/AuthRepositoryErrorTests.swift`)
- [ ] 4.2 Add `AuthRepositoryError` to `AuthRepositoryProtocol`; make tests pass

## 5. AuthRepository Protocol

- [ ] 5.1 Write failing tests: `AuthRepository` protocol compiles with `currentSession`, `currentUser`, `register`, `login`, `logout`, and `refreshSession`; mock actor type satisfies contract (`AuthRepositoryProtocolTests/AuthRepositoryTests.swift`)
- [ ] 5.2 Add `AuthRepository` protocol definition to `AuthRepositoryProtocol/AuthRepository.swift`

## 6. Test Infrastructure — URLProtocol Stub

- [ ] 6.1 Write `URLProtocolStub` test helper and JSON fixture builders for auth API responses (`AuthRepositoryTests/Support/URLProtocolStub.swift`, `AuthFixtures.swift`)
- [ ] 6.2 Verify stub can intercept requests and return configured responses in a smoke test

## 7. Internal API Client

- [ ] 7.1 Write failing tests: internal `AuthAPIClient` sends correct HTTP method, path, headers, and JSON body for register, login, logout, and refresh (`AuthRepositoryTests/AuthAPIClientTests.swift`)
- [ ] 7.2 Implement internal `AuthAPIClient` and `AuthResponseDTO` types in `AuthRepository/Internal/`; make tests pass

## 8. NetworkAuthRepository — Register

- [ ] 8.1 Write failing tests: `register` parses `201` response and stores session/user; maps `409 email_already_exists`; maps `400 validation_error`; rejects empty credentials locally (`AuthRepositoryTests/NetworkAuthRepositoryRegisterTests.swift`)
- [ ] 8.2 Implement `register` in `actor NetworkAuthRepository`; make tests pass

## 9. NetworkAuthRepository — Login

- [ ] 9.1 Write failing tests: `login` parses `200` response and stores session/user; maps `401 invalid_credentials`; rejects empty credentials locally (`AuthRepositoryTests/NetworkAuthRepositoryLoginTests.swift`)
- [ ] 9.2 Implement `login` in `NetworkAuthRepository`; make tests pass

## 10. NetworkAuthRepository — Logout

- [ ] 10.1 Write failing tests: `logout` sends Bearer token; clears state on `204`; clears state on network failure (`AuthRepositoryTests/NetworkAuthRepositoryLogoutTests.swift`)
- [ ] 10.2 Implement `logout` in `NetworkAuthRepository`; make tests pass

## 11. NetworkAuthRepository — Refresh

- [ ] 11.1 Write failing tests: `refreshSession` updates tokens on `200`; throws `notAuthenticated` when no session; maps `401 unauthorized` from server (`AuthRepositoryTests/NetworkAuthRepositoryRefreshTests.swift`)
- [ ] 11.2 Implement `refreshSession` in `NetworkAuthRepository`; make tests pass

## 12. NetworkAuthRepository — Error Mapping

- [ ] 12.1 Write failing tests: transport failure throws `networkError`; unhandled status (e.g. `500`) throws `serverError(statusCode:)` (`AuthRepositoryTests/NetworkAuthRepositoryErrorTests.swift`)
- [ ] 12.2 Implement error mapping in `AuthAPIClient` / `NetworkAuthRepository`; make tests pass

## 13. Module Integration

- [ ] 13.1 Add `@_exported import AuthRepositoryProtocol` to `AuthRepository` module entry point
- [ ] 13.2 Verify all `AuthRepositoryProtocolTests` and `AuthRepositoryTests` pass
- [ ] 13.3 Add `Packages/AuthFlow/README.md` with module dependency diagram, REST API summary, and import guidance
