## ADDED Requirements

### Requirement: Face ID usage description

The app target SHALL declare `NSFaceIDUsageDescription` in the generated Info.plist with a user-facing purpose string explaining that Face ID or Touch ID is used to unlock the encrypted notes vault.

#### Scenario: Face ID string present in app Info.plist

- **WHEN** the app target is built for Release
- **THEN** the generated Info.plist contains a non-empty `NSFaceIDUsageDescription` key

### Requirement: Privacy manifest for UserDefaults

The app target SHALL include a `PrivacyInfo.xcprivacy` resource declaring use of the UserDefaults required-reason API with reason code `CA92.1` (app functionality not linked to third-party data).

#### Scenario: Privacy manifest bundled in app

- **WHEN** the app target is built for Release
- **THEN** the app bundle contains `PrivacyInfo.xcprivacy` with a `NSPrivacyAccessedAPICategoryUserDefaults` entry and reason `CA92.1`

### Requirement: Human-readable display name

The app target SHALL set `CFBundleDisplayName` to **Super Secure Notes** so the home screen shows a human-readable name instead of the target identifier.

#### Scenario: Display name on home screen

- **WHEN** the app is installed on an iPhone
- **THEN** the home screen label reads **Super Secure Notes**

### Requirement: iPhone-only device target

The app target SHALL set `TARGETED_DEVICE_FAMILY` to `1` (iPhone only). iPad SHALL NOT be a supported destination for v1.

#### Scenario: App target is iPhone only

- **WHEN** the app target build settings are inspected
- **THEN** `TARGETED_DEVICE_FAMILY` is `1`

### Requirement: App Store marketing icon without alpha

The app icon asset catalog SHALL provide a 1024×1024 marketing icon as an RGB PNG with no alpha channel (no transparency).

#### Scenario: Marketing icon has no alpha channel

- **WHEN** the 1024×1024 app icon PNG in `AppIcon.appiconset` is inspected
- **THEN** the image has no alpha channel (RGB only)

### Requirement: Production API base URL includes version prefix

`AppDependencies.apiBaseURL` SHALL be `https://super-secure-notes-api.onrender.com/v1` in all build configurations. Network clients SHALL append paths such as `auth/login` relative to this base URL.

#### Scenario: Base URL ends with v1

- **WHEN** `AppDependencies.apiBaseURL` is read at runtime
- **THEN** its absolute string is `https://super-secure-notes-api.onrender.com/v1`

#### Scenario: Auth register hits versioned path

- **WHEN** `NetworkAuthRepository` sends a register request
- **THEN** the request URL path begins with `/v1/auth/`

### Requirement: Encryption export compliance not mis-declared

The app SHALL NOT set `ITSAppUsesNonExemptEncryption` to `false` in the Info.plist. Export compliance SHALL be completed in App Store Connect at submission time (documented in change design, not automated in code).

#### Scenario: No false encryption exemption in plist

- **WHEN** the app target Info.plist is inspected
- **THEN** `ITSAppUsesNonExemptEncryption` is not set to `false`
