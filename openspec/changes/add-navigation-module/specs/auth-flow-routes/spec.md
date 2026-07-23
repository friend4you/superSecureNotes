## ADDED Requirements

### Requirement: AuthFlowRoutes package target

The `AuthFlow` package SHALL expose a library product `AuthFlowRoutes` backed by a target that depends only on `NavigationProtocol`. The target SHALL define a public `AuthRoute` enum conforming to `Route`.

#### Scenario: AuthFlowRoutes builds independently

- **WHEN** the `AuthFlowRoutes` target is built
- **THEN** it compiles with only `NavigationProtocol` as a project dependency

#### Scenario: AuthRoute cases for auth screens

- **WHEN** `AuthRoute` is defined
- **THEN** it includes cases for login and register screens

### Requirement: AuthFlowRoutes import boundary

Other modules that need to navigate to auth screens SHALL depend on `AuthFlowRoutes` only, not on `AuthFlowUI`.

#### Scenario: Cross-module auth navigation without UI import

- **WHEN** a consumer imports `AuthFlowRoutes`
- **THEN** it can reference `AuthRoute` without importing `AuthFlowUI`
