## ADDED Requirements

### Requirement: Settings sheet presentation chrome

`BiometricSettingsView` (or the view returned by `AuthNavigation.settingsView`) SHALL be wrapped in a `NavigationStack` when presented as a sheet. The sheet SHALL include a Done (cancellation) toolbar button that calls `navigator.dismissPresentation()`.

#### Scenario: Settings sheet has navigation stack

- **WHEN** settings is presented as a sheet from the notes list
- **THEN** the presented content is wrapped in a `NavigationStack` with a visible navigation title

#### Scenario: Done dismisses settings sheet

- **WHEN** the user taps Done on the settings sheet
- **THEN** `navigator.dismissPresentation()` is called

### Requirement: Settings logout action

The settings screen SHALL expose a production logout button (not gated by `#if DEBUG`) that invokes the app-composed `performLogout` closure. Logout behavior SHALL match the existing session-lock full reset (credentials cleared, vault session cleared, navigation to login).

#### Scenario: Logout button visible in production builds

- **WHEN** `BiometricSettingsView` is rendered in a release build
- **THEN** a logout action is visible on the settings screen

#### Scenario: Logout invokes performLogout

- **WHEN** the user taps logout on the settings screen
- **THEN** the settings view model calls the injected `performLogout` closure

#### Scenario: Logout not on notes list

- **WHEN** the notes list screen is shown
- **THEN** logout is not available from the list toolbar; it is only reachable from settings

### Requirement: Settings view model logout dependency

`DefaultBiometricSettingsViewModel` SHALL accept `performLogout: () async -> Void` and `Navigating` via `AuthFlowDependencyProviding.makeBiometricSettingsViewModel()`. `AppComposition` SHALL pass the same `performLogout` closure used by notes flow logout.

#### Scenario: Settings VM factory receives performLogout

- **WHEN** `AuthFlowDependencies.makeBiometricSettingsViewModel()` is called from app composition
- **THEN** the returned view model is configured with the shared `performLogout` closure
