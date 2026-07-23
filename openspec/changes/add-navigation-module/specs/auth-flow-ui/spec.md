## ADDED Requirements

### Requirement: AuthFlowDependencyProviding protocol

`AuthFlowUI` or `AuthFlowProtocol` SHALL expose a public `@MainActor` protocol `AuthFlowDependencyProviding` that declares factory methods for auth view models required by auth screens. Concrete implementations SHALL NOT be public from the AuthFlow package.

#### Scenario: Protocol is public

- **WHEN** a consumer imports the module exporting `AuthFlowDependencyProviding`
- **THEN** the protocol type is accessible

#### Scenario: Protocol provides login and register view models

- **WHEN** `AuthFlowDependencyProviding` is inspected
- **THEN** it includes methods to create login and register view models

### Requirement: AuthNavigation view builder

`AuthFlowUI` SHALL provide an internal `AuthNavigation` type with a static `view(for:deps:)` method that maps each `AuthRoute` case to the corresponding SwiftUI screen using `any AuthFlowDependencyProviding`.

#### Scenario: Login route builds LoginView

- **WHEN** `AuthNavigation.view(for: .login, deps:)` is called with a test double conforming to `AuthFlowDependencyProviding`
- **THEN** a `LoginView` is produced

#### Scenario: Register route builds RegisterView

- **WHEN** `AuthNavigation.view(for: .register, deps:)` is called
- **THEN** a `RegisterView` is produced

### Requirement: Auth screens use NavigationRouting instead of NavigationLink

`LoginView` SHALL NOT use `NavigationLink` to reach `RegisterView`. Register navigation SHALL be triggered via `NavigationRouting.push(AuthRoute.register)` (or equivalent router API).

#### Scenario: LoginView has no NavigationLink to register

- **WHEN** `LoginView` source is inspected
- **THEN** it does not contain a `NavigationLink` to `RegisterView`

#### Scenario: Register navigation uses AuthRoute

- **WHEN** the user initiates register navigation from login
- **THEN** the router receives `AuthRoute.register`

### Requirement: LoginView initializer change

`LoginView` SHALL accept a `LoginViewModel` and obtain `NavigationRouting` from the SwiftUI environment (or explicit injection). It SHALL NOT require a `makeRegisterViewModel` closure for navigation purposes.

#### Scenario: LoginView does not require register factory for navigation

- **WHEN** `LoginView` is constructed for production use
- **THEN** its initializer does not require `makeRegisterViewModel` solely to navigate to register
