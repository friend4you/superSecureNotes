## ADDED Requirements

### Requirement: AuthFlow UI package module boundary

The `AuthFlow` package SHALL be extended with two new library products: `AuthFlowProtocol` (ViewModel contracts, state types, `VaultAuthenticator` protocol) and `AuthFlowUI` (SwiftUI views, default ViewModels, localization resources). `AuthFlowProtocol` SHALL depend on `AuthRepositoryProtocol`, `VaultRepositoryProtocol`, and `VaultSessionProtocol` only. `AuthFlowUI` SHALL depend on `AuthFlowProtocol` and `SecureCrypto`. The package SHALL support iOS 17+ and macOS 13+.

#### Scenario: Package builds with new UI targets

- **WHEN** the `AuthFlow` package is built
- **THEN** `AuthFlowProtocol` and `AuthFlowUI` targets compile successfully alongside existing repository targets

#### Scenario: Protocol module has no SwiftUI dependency

- **WHEN** `AuthFlowProtocol` is built
- **THEN** it does not import SwiftUI

#### Scenario: UI module depends on SecureCrypto

- **WHEN** `AuthFlowUI` is built
- **THEN** it links `SecureCrypto` for the default `VaultAuthenticator` implementation

### Requirement: Auth form state and error types

`AuthFlowProtocol` SHALL define `AuthFormState` with cases `idle`, `loading`, and `failure(AuthFlowError)`. It SHALL define `AuthFlowError` with cases: `invalidCredentials`, `emailAlreadyExists`, `validationError`, `vaultNotFound`, `vaultUnlockFailed`, `networkError`, and `unknown`. Both types SHALL conform to `Equatable` and `Sendable`.

#### Scenario: Auth form states are equatable

- **WHEN** two `AuthFormState` values of the same case are compared
- **THEN** they are equal

#### Scenario: Auth flow errors are equatable

- **WHEN** two `AuthFlowError` values of the same case are compared
- **THEN** they are equal

### Requirement: VaultAuthenticator protocol

`AuthFlowProtocol` SHALL define a `VaultAuthenticator` protocol with `createVault(password:)` returning `VaultCreationOutcome` and `unlockVault(headerData:password:)` returning `VaultUnlockOutcome`. `VaultCreationOutcome` SHALL contain `headerData: Data` and `mnemonic: [String]`. `VaultUnlockOutcome` SHALL contain `sessionKeys: VaultSessionKeys`.

#### Scenario: VaultAuthenticator create contract compiles

- **WHEN** a mock type conforms to `VaultAuthenticator`
- **THEN** `createVault(password:)` can be called and returns `VaultCreationOutcome`

#### Scenario: VaultAuthenticator unlock contract compiles

- **WHEN** a mock type conforms to `VaultAuthenticator`
- **THEN** `unlockVault(headerData:password:)` can be called and returns `VaultUnlockOutcome`

### Requirement: LoginViewModel protocol

`AuthFlowProtocol` SHALL define a `@MainActor` `LoginViewModel` protocol with `email`, `password`, `state: AuthFormState`, and `login() async`. The protocol SHALL conform to `Observable`.

#### Scenario: LoginViewModel initial state is idle

- **WHEN** a new `LoginViewModel` implementation is created
- **THEN** `state` is `idle`, `email` is empty, and `password` is empty

#### Scenario: Login transitions to loading during login

- **WHEN** `login()` is called
- **THEN** `state` becomes `loading` before the async operation completes

#### Scenario: Login succeeds and establishes vault session

- **WHEN** `login()` is called with valid credentials, `AuthRepository.login` succeeds, `VaultRepository.readHeader` returns header data, and `VaultAuthenticator.unlockVault` succeeds
- **THEN** `VaultSessionProtocol.establish` is called with the unlock outcome keys and `state` returns to `idle`

#### Scenario: Login maps invalid credentials

- **WHEN** `login()` is called and `AuthRepository.login` throws `AuthRepositoryError.invalidCredentials`
- **THEN** `state` becomes `failure(.invalidCredentials)`

#### Scenario: Login maps vault not found

- **WHEN** `login()` succeeds at account level but `VaultRepository.readHeader` throws `VaultRepositoryError.headerNotFound`
- **THEN** `state` becomes `failure(.vaultNotFound)`

#### Scenario: Login maps vault unlock failure

- **WHEN** account login and header fetch succeed but `VaultAuthenticator.unlockVault` throws
- **THEN** `state` becomes `failure(.vaultUnlockFailed)`

#### Scenario: Login maps network error

- **WHEN** `login()` is called and a repository throws `networkError`
- **THEN** `state` becomes `failure(.networkError)`

#### Scenario: Login rejects empty fields locally

- **WHEN** `login()` is called with empty email or empty password
- **THEN** `state` becomes `failure(.validationError)` without calling `AuthRepository.login`

### Requirement: RegisterViewModel protocol

`AuthFlowProtocol` SHALL define a `@MainActor` `RegisterViewModel` protocol with `email`, `password`, `state: AuthFormState`, and `register() async`. The protocol SHALL conform to `Observable`.

#### Scenario: RegisterViewModel initial state is idle

- **WHEN** a new `RegisterViewModel` implementation is created
- **THEN** `state` is `idle`, `email` is empty, and `password` is empty

#### Scenario: Register transitions to loading during register

- **WHEN** `register()` is called
- **THEN** `state` becomes `loading` before the async operation completes

#### Scenario: Register succeeds and uploads vault header

- **WHEN** `register()` is called with valid credentials, `AuthRepository.register` succeeds, `VaultAuthenticator.createVault` succeeds, and `VaultRepository.writeHeader` succeeds
- **THEN** `VaultSessionProtocol.establish` is called and `state` returns to `idle`

#### Scenario: Register maps email already exists

- **WHEN** `register()` is called and `AuthRepository.register` throws `AuthRepositoryError.emailAlreadyExists`
- **THEN** `state` becomes `failure(.emailAlreadyExists)`

#### Scenario: Register maps validation error

- **WHEN** `register()` is called and `AuthRepository.register` throws `AuthRepositoryError.validationError`
- **THEN** `state` becomes `failure(.validationError)`

#### Scenario: Register rejects empty fields locally

- **WHEN** `register()` is called with empty email or empty password
- **THEN** `state` becomes `failure(.validationError)` without calling `AuthRepository.register`

#### Scenario: Register maps vault upload failure

- **WHEN** account registration and vault creation succeed but `VaultRepository.writeHeader` throws
- **THEN** `state` becomes `failure(.networkError)`

### Requirement: LoginView screen

`AuthFlowUI` SHALL expose a public `LoginView` that accepts a `LoginViewModel` via initializer. The view SHALL display localized email and password fields, a localized submit button, a localized link to registration, and a localized error message when `state` is `failure`.

#### Scenario: LoginView is publicly constructible

- **WHEN** a consumer imports `AuthFlowUI` and creates `LoginView(viewModel:)`
- **THEN** the type compiles and can be used in a SwiftUI view hierarchy

#### Scenario: LoginView shows localized title

- **WHEN** `LoginView` is rendered
- **THEN** the title text is resolved from `Localizable.xcstrings` via the module bundle

#### Scenario: LoginView navigates to register

- **WHEN** the user taps the register navigation control
- **THEN** `RegisterView` is presented in the navigation hierarchy

### Requirement: RegisterView screen

`AuthFlowUI` SHALL expose a public `RegisterView` that accepts a `RegisterViewModel` via initializer. The view SHALL display localized email and password fields, a localized submit button, a localized link to login, and a localized error message when `state` is `failure`.

#### Scenario: RegisterView is publicly constructible

- **WHEN** a consumer imports `AuthFlowUI` and creates `RegisterView(viewModel:)`
- **THEN** the type compiles and can be used in a SwiftUI view hierarchy

#### Scenario: RegisterView shows localized title

- **WHEN** `RegisterView` is rendered
- **THEN** the title text is resolved from `Localizable.xcstrings` via the module bundle

### Requirement: Localized strings catalog

All user-visible strings in `AuthFlowUI` views SHALL be defined in `Resources/Localizable.xcstrings`. Views SHALL resolve strings using the module bundle. No hardcoded user-facing display strings SHALL appear in SwiftUI view bodies.

#### Scenario: String catalog is bundled with AuthFlowUI

- **WHEN** the `AuthFlowUI` target is built
- **THEN** `Localizable.xcstrings` is included as a processed resource

#### Scenario: Error messages are localized in views

- **WHEN** a ViewModel enters `failure` state
- **THEN** the view displays a localized string keyed by the `AuthFlowError` case

### Requirement: Default ViewModel implementations

`AuthFlowUI` SHALL provide `DefaultLoginViewModel` and `DefaultRegisterViewModel` conforming to the respective protocols. Each SHALL accept `AuthRepository`, `VaultRepository`, `VaultAuthenticator`, and `VaultSessionProtocol` via initializer injection.

#### Scenario: Default login view model is constructible

- **WHEN** dependencies are provided to `DefaultLoginViewModel` init
- **THEN** the instance conforms to `LoginViewModel`

#### Scenario: Default register view model is constructible

- **WHEN** dependencies are provided to `DefaultRegisterViewModel` init
- **THEN** the instance conforms to `RegisterViewModel`

### Requirement: SecureCryptoVaultAuthenticator

`AuthFlowUI` SHALL provide `SecureCryptoVaultAuthenticator` conforming to `VaultAuthenticator`, delegating to `SecureCrypto` vault lifecycle functions.

#### Scenario: Default authenticator uses SecureCrypto create

- **WHEN** `SecureCryptoVaultAuthenticator.createVault` is called with a non-empty password
- **THEN** it returns serialized header data and mnemonic words from `createVault`

#### Scenario: Default authenticator uses SecureCrypto unlock

- **WHEN** `SecureCryptoVaultAuthenticator.unlockVault` is called with valid header data and password
- **THEN** it returns `VaultSessionKeys` with UDK and identity private key

### Requirement: AuthRepository AccessTokenProviding adapter

The `AuthRepository` target SHALL provide `AuthRepositoryAccessTokenProvider` conforming to `AccessTokenProviding`, returning `currentSession.accessToken` from an injected `AuthRepository` or throwing `VaultRepositoryError.notAuthenticated` when no session exists.

#### Scenario: Token provider returns access token when authenticated

- **WHEN** `accessToken()` is called and the repository has an active session
- **THEN** the access token string is returned

#### Scenario: Token provider throws when not authenticated

- **WHEN** `accessToken()` is called and `currentSession` is `nil`
- **THEN** `VaultRepositoryError.notAuthenticated` is thrown

### Requirement: App presents auth UI when unauthenticated

The `superSecureNotes` app target SHALL link `AuthFlowUI`, `VaultRepository`, and `VaultSession` products. When `VaultSession` is not active, the app root SHALL present `LoginView`. When `VaultSession` is active, the app root SHALL present `NoteListView`.

#### Scenario: App shows login when vault session inactive

- **WHEN** the app launches with no active vault session
- **THEN** `LoginView` is shown in the view hierarchy

#### Scenario: App shows notes when vault session active

- **WHEN** the user completes login and `VaultSession.establish` has been called
- **THEN** `NoteListView` is shown in the view hierarchy

### Requirement: SwiftUI preview support

`AuthFlowUI` SHALL include `#Preview` providers for `LoginView` and `RegisterView` using mock ViewModels.

#### Scenario: LoginView preview compiles

- **WHEN** the `AuthFlowUI` package is built with SwiftUI previews enabled
- **THEN** the `LoginView` preview compiles successfully

#### Scenario: RegisterView preview compiles

- **WHEN** the `AuthFlowUI` package is built with SwiftUI previews enabled
- **THEN** the `RegisterView` preview compiles successfully
