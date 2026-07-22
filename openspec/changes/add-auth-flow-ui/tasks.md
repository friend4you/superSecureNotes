## 1. Package Structure

- [x] 1.1 Extend `Packages/AuthFlow/Package.swift` with `AuthFlowProtocol` and `AuthFlowUI` products/targets; add path dependencies on `VaultRepository`, `SecureCrypto`, and `VaultSession`; add `AuthFlowProtocolTests` and `AuthFlowUITests` test targets
- [x] 1.2 Scaffold `Sources/AuthFlowProtocol/` and `Sources/AuthFlowUI/` module entry points with `@_exported import` from `AuthFlowUI`
- [x] 1.3 Add `AuthFlowUI`, `VaultRepository`, and `VaultSession` package products to Xcode project app target

## 2. Auth Form State and Error Types

- [x] 2.1 Write failing tests: `AuthFormState` and `AuthFlowError` are `Equatable` and `Sendable`; all error cases compare equal (`AuthFlowProtocolTests/AuthFormStateTests.swift`)
- [x] 2.2 Add `AuthFormState` and `AuthFlowError` to `AuthFlowProtocol`; make tests pass

## 3. VaultAuthenticator Protocol

- [x] 3.1 Write failing tests: `VaultCreationOutcome` and `VaultUnlockOutcome` hold expected fields; mock `VaultAuthenticator` satisfies protocol (`AuthFlowProtocolTests/VaultAuthenticatorTests.swift`)
- [x] 3.2 Add `VaultAuthenticator`, `VaultCreationOutcome`, and `VaultUnlockOutcome` to `AuthFlowProtocol`; make tests pass

## 4. LoginViewModel Protocol

- [x] 4.1 Write failing tests: `LoginViewModel` protocol compiles; mock type satisfies contract with initial idle state (`AuthFlowProtocolTests/LoginViewModelTests.swift`)
- [x] 4.2 Add `LoginViewModel` protocol to `AuthFlowProtocol/LoginViewModel.swift`

## 5. RegisterViewModel Protocol

- [x] 5.1 Write failing tests: `RegisterViewModel` protocol compiles; mock type satisfies contract with initial idle state (`AuthFlowProtocolTests/RegisterViewModelTests.swift`)
- [x] 5.2 Add `RegisterViewModel` protocol to `AuthFlowProtocol/RegisterViewModel.swift`

## 6. Test Infrastructure — ViewModel Mocks

- [x] 6.1 Write mock `AuthRepository`, `VaultRepository`, `VaultAuthenticator`, and `VaultSession` test doubles (`AuthFlowProtocolTests/Support/AuthFlowMocks.swift`)
- [x] 6.2 Verify mocks are usable in a smoke test

## 7. DefaultLoginViewModel — Validation and State

- [x] 7.1 Write failing tests: empty email/password sets `failure(.validationError)` without calling repository; `login()` sets `loading` during operation (`AuthFlowProtocolTests/DefaultLoginViewModelTests.swift` — scenarios: Login rejects empty fields locally, Login transitions to loading)
- [x] 7.2 Implement `DefaultLoginViewModel` validation and loading state; make tests pass

## 8. DefaultLoginViewModel — Success Path

- [x] 8.1 Write failing tests: successful login calls `AuthRepository.login`, `VaultRepository.readHeader`, `VaultAuthenticator.unlockVault`, and `VaultSession.establish`; returns to `idle` (`AuthFlowProtocolTests/DefaultLoginViewModelSuccessTests.swift` — scenario: Login succeeds and establishes vault session)
- [x] 8.2 Implement login orchestration success path; make tests pass

## 9. DefaultLoginViewModel — Error Mapping

- [x] 9.1 Write failing tests: maps `invalidCredentials`, `headerNotFound` → `vaultNotFound`, unlock failure → `vaultUnlockFailed`, network errors (`AuthFlowProtocolTests/DefaultLoginViewModelErrorTests.swift` — scenarios: Login maps invalid credentials, vault not found, vault unlock failure, network error)
- [x] 9.2 Implement login error mapping; make tests pass

## 10. DefaultRegisterViewModel — Validation and State

- [x] 10.1 Write failing tests: empty email/password sets `failure(.validationError)`; `register()` sets `loading` (`AuthFlowProtocolTests/DefaultRegisterViewModelTests.swift` — scenarios: Register rejects empty fields locally, Register transitions to loading)
- [x] 10.2 Implement `DefaultRegisterViewModel` validation and loading state; make tests pass

## 11. DefaultRegisterViewModel — Success Path

- [x] 11.1 Write failing tests: successful register calls `AuthRepository.register`, `VaultAuthenticator.createVault`, `VaultRepository.writeHeader`, and `VaultSession.establish`; returns to `idle` (`AuthFlowProtocolTests/DefaultRegisterViewModelSuccessTests.swift` — scenario: Register succeeds and uploads vault header)
- [x] 11.2 Implement register orchestration success path; make tests pass

## 12. DefaultRegisterViewModel — Error Mapping

- [x] 12.1 Write failing tests: maps `emailAlreadyExists`, `validationError`, vault upload failure → `networkError` (`AuthFlowProtocolTests/DefaultRegisterViewModelErrorTests.swift` — scenarios: Register maps email already exists, validation error, vault upload failure)
- [x] 12.2 Implement register error mapping; make tests pass

## 13. SecureCryptoVaultAuthenticator

- [x] 13.1 Write failing tests: `createVault` returns serialized header and mnemonic; `unlockVault` returns `VaultSessionKeys` (`AuthFlowUITests/SecureCryptoVaultAuthenticatorTests.swift` — scenarios: Default authenticator uses SecureCrypto create/unlock)
- [x] 13.2 Implement `SecureCryptoVaultAuthenticator` in `AuthFlowUI`; make tests pass

## 14. Localization Catalog

- [x] 14.1 Create `AuthFlowUI/Resources/Localizable.xcstrings` with keys for `login.*`, `register.*`, `error.*`, and `common.*` (English)
- [x] 14.2 Write failing test: string catalog is bundled as processed resource (`AuthFlowUITests/LocalizationTests.swift` — scenario: String catalog is bundled with AuthFlowUI)
- [x] 14.3 Wire `resources: [.process("Resources")]` in `Package.swift`; make test pass

## 15. LoginView

- [x] 15.1 Write failing test: `LoginView(viewModel:)` is publicly constructible when importing `AuthFlowUI` (`AuthFlowUITests/LoginViewTests.swift` — scenario: LoginView is publicly constructible)
- [x] 15.2 Implement `LoginView` with localized email/password fields, submit button, error display, and `NavigationLink` to `RegisterView`; add `#Preview`; make test pass

## 16. RegisterView

- [x] 16.1 Write failing test: `RegisterView(viewModel:)` is publicly constructible (`AuthFlowUITests/RegisterViewTests.swift` — scenario: RegisterView is publicly constructible)
- [x] 16.2 Implement `RegisterView` with localized fields, submit button, error display, and link back to login; add `#Preview`; make test pass

## 17. AuthRepository AccessTokenProviding Adapter

- [x] 17.1 Write failing tests: `AuthRepositoryAccessTokenProvider` returns token when session exists; throws `notAuthenticated` when nil (`AuthRepositoryTests/AuthRepositoryAccessTokenProviderTests.swift` — scenarios: Token provider returns access token / throws when not authenticated)
- [x] 17.2 Implement `AuthRepositoryAccessTokenProvider` in `AuthRepository` target; add `VaultRepositoryProtocol` dependency to `AuthRepository` target in `Package.swift`; make tests pass

## 18. App Composition Root

- [x] 18.1 Wire `NetworkAuthRepository`, `AuthRepositoryAccessTokenProvider`, `NetworkVaultRepository`, `VaultSession`, and `SecureCryptoVaultAuthenticator` in app dependencies
- [x] 18.2 Update app root to show `LoginView` when vault session inactive and `NoteListView` when active (scenarios: App shows login when vault session inactive, App shows notes when vault session active)
- [x] 18.3 Build and run app; confirm login screen appears on launch

## 19. Verification

- [x] 19.1 Run `swift test` in `Packages/AuthFlow`; confirm all tests pass
- [x] 19.2 Add `Packages/AuthFlow/README.md` section for UI targets, localization, and import guidance
- [x] 19.3 Verify `#Preview` for `LoginView` and `RegisterView` compiles in Xcode
