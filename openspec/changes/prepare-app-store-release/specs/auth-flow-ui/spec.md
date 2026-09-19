## ADDED Requirements

### Requirement: Register screen privacy policy link

`RegisterView` SHALL display a tappable link to the privacy policy at `https://super-secure-notes-api.onrender.com/privacy` before or alongside the register submit action.

#### Scenario: Privacy link visible on register

- **WHEN** the register screen is shown
- **THEN** a privacy policy link is visible and opens the hosted privacy URL

### Requirement: Settings legal and support links

The settings screen (`BiometricSettingsView`) SHALL expose tappable links to the privacy policy (`https://super-secure-notes-api.onrender.com/privacy`) and support contact (`mailto:vlad.arsenyuk@gmail.com`).

#### Scenario: Privacy link in settings

- **WHEN** the settings screen is shown
- **THEN** a privacy policy link is visible

#### Scenario: Support contact in settings

- **WHEN** the settings screen is shown
- **THEN** a support contact link using `mailto:vlad.arsenyuk@gmail.com` is visible

### Requirement: Settings delete account action

The settings screen SHALL expose a destructive **Delete Account** action separate from logout. The action SHALL require explicit confirmation and password entry before proceeding.

#### Scenario: Delete account button visible

- **WHEN** the settings screen is shown in a Release build
- **THEN** a delete account action is visible and distinct from the logout action

#### Scenario: Delete requires confirmation

- **WHEN** the user initiates delete account
- **THEN** the UI prompts for confirmation before calling the delete use case

#### Scenario: Delete requires password

- **WHEN** the user confirms account deletion
- **THEN** the UI collects the account password and passes it to the delete use case

### Requirement: Delete account use case orchestration

A delete-account use case SHALL call `authRepository.deleteAccount(password:)`. On success it SHALL invoke the app-composed full local reset (same as logout: Keychain wipe, local app data wipe, vault session clear, navigation to login). On failure it SHALL surface mapped auth errors without wiping local data.

#### Scenario: Successful delete performs full local reset

- **WHEN** delete account succeeds on the server
- **THEN** local credentials and app data are wiped and the login screen is shown

#### Scenario: Failed delete preserves local data

- **WHEN** delete account fails with invalid credentials
- **THEN** local Keychain and note data remain unchanged

#### Scenario: Delete account view model dependency

- **WHEN** `AuthFlowDependencies.makeBiometricSettingsViewModel()` is called from app composition
- **THEN** the returned view model is configured with a delete-account action wired to the delete use case and full reset closure
