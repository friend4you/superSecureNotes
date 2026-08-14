## ADDED Requirements

### Requirement: AuthRoute biometric enrollment case

`AuthRoute` SHALL include a `biometricEnrollment` case for presenting the biometric enrollment screen.

#### Scenario: AuthRoute includes biometric enrollment

- **WHEN** `AuthRoute` is defined
- **THEN** it includes a `biometricEnrollment` case alongside login, register, unlock, and settings

#### Scenario: AuthFlowRoutes still depends only on NavigationProtocol

- **WHEN** the `AuthFlowRoutes` target is built
- **THEN** it compiles with only `NavigationProtocol` as a project dependency

### Requirement: AuthNavigation builds biometric enrollment view

`AuthNavigation.view(for:deps:)` SHALL map `AuthRoute.biometricEnrollment` to `BiometricEnrollmentView` using `AuthFlowDependencyProviding`.

#### Scenario: Biometric enrollment route builds BiometricEnrollmentView

- **WHEN** `AuthNavigation.view(for: .biometricEnrollment, deps:)` is called
- **THEN** a `BiometricEnrollmentView` is produced

#### Scenario: Route registry resolves biometric enrollment

- **WHEN** `RouteRegistry.registerAuthRoutes` is called and a view is requested for `AuthRoute.biometricEnrollment`
- **THEN** the registered factory returns a view for that route
