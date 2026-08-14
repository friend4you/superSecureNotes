## ADDED Requirements

### Requirement: Auth form views use section builders

`LoginView`, `RegisterView`, and `UnlockView` SHALL structure `body` as a `Form` containing `credentialsSection`, `errorSection`, and `actionsSection` implemented as private `@ViewBuilder` properties. The `body` property SHALL not contain inline multi-line field or button layout beyond calling those section builders and view modifiers.

#### Scenario: LoginView body uses section builders

- **WHEN** `LoginView` source is inspected
- **THEN** `body` references `credentialsSection`, `errorSection`, and `actionsSection` as separate `@ViewBuilder` properties

#### Scenario: RegisterView body uses section builders

- **WHEN** `RegisterView` source is inspected
- **THEN** `body` references `credentialsSection`, `errorSection`, and `actionsSection` as separate `@ViewBuilder` properties

#### Scenario: UnlockView body uses section builders

- **WHEN** `UnlockView` source is inspected
- **THEN** `body` references `credentialsSection`, `errorSection`, and `actionsSection` as separate `@ViewBuilder` properties

### Requirement: String Catalog generated symbols

`AuthFlowUI` SHALL enable String Catalog symbol generation for `Localizable.xcstrings`. All user-visible strings in auth views and `AuthFlowErrorText` SHALL use generated localization symbols instead of raw string keys or `AuthFlowUILocalization`. The `AuthFlowUILocalization` type SHALL be removed.

#### Scenario: Views use generated symbols

- **WHEN** `LoginView`, `RegisterView`, `UnlockView`, or `BiometricEnrollmentView` source is inspected
- **THEN** user-visible strings use generated String Catalog symbols, not `String(localized: "key", bundle: .module)` or `AuthFlowUILocalization`

#### Scenario: Error text uses generated symbols

- **WHEN** `AuthFlowErrorText` source is inspected
- **THEN** error messages resolve via generated symbols keyed by `AuthFlowError` case

#### Scenario: AuthFlowUILocalization is removed

- **WHEN** the `AuthFlowUI` target sources are inspected
- **THEN** `AuthFlowUILocalization.swift` is not present

### Requirement: Biometric enrollment via navigator

After first-time login or register success, auth view models SHALL present biometric enrollment via `navigator.present(AuthRoute.biometricEnrollment, style: .sheet)`. `LoginView` and `RegisterView` SHALL NOT attach `.sheet` modifiers for enrollment. View models SHALL NOT expose `pendingBiometricEnrollment`, `makeBiometricEnrollmentViewModel()`, or `dismissBiometricEnrollment()`.

#### Scenario: LoginView has no enrollment sheet

- **WHEN** `LoginView` source is inspected
- **THEN** it does not contain `.sheet` or `biometricEnrollmentSheetBinding`

#### Scenario: RegisterView has no enrollment sheet

- **WHEN** `RegisterView` source is inspected
- **THEN** it does not contain `.sheet` or `biometricEnrollmentSheetBinding`

#### Scenario: First-time login presents enrollment route

- **WHEN** login succeeds with `wasFirstSetup` equal to `true`
- **THEN** `navigator.present(AuthRoute.biometricEnrollment, style: .sheet)` is called

#### Scenario: First-time register presents enrollment route

- **WHEN** register succeeds with `wasFirstSetup` equal to `true`
- **THEN** `navigator.present(AuthRoute.biometricEnrollment, style: .sheet)` is called

#### Scenario: Repeat login does not present enrollment

- **WHEN** login succeeds with `wasFirstSetup` equal to `false`
- **THEN** enrollment route is not presented

### Requirement: Biometric enrollment dismisses via navigator

`DefaultBiometricEnrollmentViewModel` SHALL accept `Navigating` and call `dismissPresentation()` when the user enables biometrics or skips enrollment. It SHALL NOT require an `onComplete` closure from login or register view models.

#### Scenario: Skip dismisses presentation

- **WHEN** the user taps skip on biometric enrollment
- **THEN** `navigator.dismissPresentation()` is called

#### Scenario: Enable dismisses presentation after success

- **WHEN** the user enables biometrics successfully
- **THEN** `navigator.dismissPresentation()` is called

#### Scenario: Enrollment view model does not use onComplete closure

- **WHEN** `DefaultBiometricEnrollmentViewModel` initializer is inspected
- **THEN** it does not require an `onComplete` parameter from login or register view models

### Requirement: Register view model has navigator

`DefaultRegisterViewModel` SHALL accept `navigator: any Navigating` via initializer injection for enrollment presentation, matching `DefaultLoginViewModel`.

#### Scenario: Register view model can present enrollment

- **WHEN** `DefaultRegisterViewModel` is constructed with a test navigator
- **THEN** first-time register success presents `AuthRoute.biometricEnrollment` via that navigator

## MODIFIED Requirements

### Requirement: Localized strings catalog

All user-visible strings in `AuthFlowUI` views SHALL be defined in `Resources/Localizable.xcstrings` with generated Swift symbols enabled. Views and `AuthFlowErrorText` SHALL resolve strings via generated symbols. No hardcoded user-facing display strings SHALL appear in SwiftUI view bodies.

#### Scenario: String catalog is bundled with AuthFlowUI

- **WHEN** the `AuthFlowUI` target is built
- **THEN** `Localizable.xcstrings` is included as a processed resource

#### Scenario: Error messages are localized in views

- **WHEN** a ViewModel enters `failure` state
- **THEN** the view displays a localized string keyed by the `AuthFlowError` case via generated symbols

#### Scenario: String catalog symbols are generated

- **WHEN** the `AuthFlowUI` target is built with symbol generation enabled
- **THEN** Swift symbols for catalog keys are available to auth views

### Requirement: Default ViewModel implementations

`AuthFlowProtocol` SHALL provide `DefaultLoginViewModel`, `DefaultRegisterViewModel`, and `DefaultUnlockViewModel` conforming to the respective protocols. Each SHALL accept use case protocols from `AuthFlowDomainProtocol` via initializer injection. `DefaultLoginViewModel` and `DefaultRegisterViewModel` SHALL accept `navigator: any Navigating`. View models SHALL orchestrate state transitions and navigation; they SHALL NOT contain direct multi-step auth repository orchestration logic.

#### Scenario: Default login view model is constructible

- **WHEN** use cases and navigator are provided to `DefaultLoginViewModel` init
- **THEN** the instance conforms to `LoginViewModel`

#### Scenario: Default register view model is constructible

- **WHEN** use cases and navigator are provided to `DefaultRegisterViewModel` init
- **THEN** the instance conforms to `RegisterViewModel`

#### Scenario: Default unlock view model is constructible

- **WHEN** use cases are provided to `DefaultUnlockViewModel` init
- **THEN** the instance conforms to `UnlockViewModel`

#### Scenario: Login view model delegates to LoginUseCase

- **WHEN** `DefaultLoginViewModel.login` completes successfully
- **THEN** `LoginUseCase.execute` was invoked and `state` returns to `idle`

#### Scenario: Register view model delegates to RegisterUseCase

- **WHEN** `DefaultRegisterViewModel.register` completes successfully
- **THEN** `RegisterUseCase.execute` was invoked and `state` returns to `idle`
