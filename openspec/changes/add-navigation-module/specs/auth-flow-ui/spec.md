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

### Requirement: Auth screens use Navigating from deps instead of NavigationLink

`LoginView` SHALL NOT use `NavigationLink` to reach `RegisterView`. Register navigation SHALL be triggered via `Navigating.push(AuthRoute.register)` on the view model, which obtains `Navigating` from the deps bag.

#### Scenario: LoginView has no NavigationLink to register

- **WHEN** `LoginView` source is inspected
- **THEN** it does not contain a `NavigationLink` to `RegisterView`

#### Scenario: Register navigation uses AuthRoute

- **WHEN** the user initiates register navigation from login
- **THEN** the navigator receives `AuthRoute.register`

### Requirement: LoginView initializer change

`LoginView` SHALL accept a `LoginViewModel`. The view model SHALL obtain `Navigating` from the deps bag. `LoginView` SHALL NOT require a `makeRegisterViewModel` closure for navigation purposes and SHALL NOT read `NavigationRouting` from the SwiftUI environment.

#### Scenario: LoginView does not require register factory for navigation

- **WHEN** `LoginView` is constructed for production use
- **THEN** its initializer does not require `makeRegisterViewModel` solely to navigate to register

#### Scenario: LoginView does not use environment router

- **WHEN** `LoginView` source is inspected
- **THEN** it does not reference `navigationRouter` from the environment
