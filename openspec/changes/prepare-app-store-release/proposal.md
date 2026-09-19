## Why

The app cannot pass App Store review in its current state: the Release binary is missing required privacy metadata (Face ID usage string, privacy manifest), the marketing icon has an alpha channel, the device target still includes iPad, and users can register accounts but cannot delete them in-app. Production API wiring also needs a `/v1` base URL. This change makes the iOS client review-ready for an iPhone-only v1 release.

## What Changes

- **App target / Xcode:** Add `NSFaceIDUsageDescription`, `PrivacyInfo.xcprivacy` (UserDefaults CA92.1), human display name **Super Secure Notes**, iPhone-only target (`TARGETED_DEVICE_FAMILY = 1`), flatten 1024×1024 app icon to RGB (no alpha)
- **API base URL:** Set `AppDependencies.apiBaseURL` to `https://super-secure-notes-api.onrender.com/v1` (Release and Debug)
- **Account deletion:** Add `AuthRepository.deleteAccount(password:)` calling `POST /v1/auth/delete-account` with Bearer token and password body; on success perform the same local wipe as logout
- **Settings UI:** Add destructive **Delete Account** flow with confirmation and password entry; keep existing logout row
- **Legal links:** Add privacy policy link on register screen and in settings (`https://super-secure-notes-api.onrender.com/privacy`); add support contact (`mailto:vlad.arsenyuk@gmail.com`) in settings. Terms of Service deferred to a follow-up change
- **Session lifecycle:** Document that account deletion is distinct from logout (server user removed vs local-only reset)

## Capabilities

### New Capabilities

- `app-store-compliance`: Binary and Info.plist requirements for App Store submission (Face ID string, privacy manifest, display name, iPhone-only, icon, production base URL)

### Modified Capabilities

- `auth-flow-repository`: Add account deletion API client and repository method
- `auth-flow-ui`: Settings delete-account flow, privacy and support links on register and settings
- `session-lock`: Account deletion full reset behavior after server-side hard delete

## Impact

- `superSecureNotes.xcodeproj/project.pbxproj` — Info.plist keys, device family, optional encryption plist note
- `superSecureNotes/` — `PrivacyInfo.xcprivacy`, app icon asset, `AppDependencies.swift`
- `superSecureNotesTests/AppDependenciesTests.swift` — base URL assertion
- `Packages/AuthFlow/Sources/AuthRepositoryProtocol/` — `deleteAccount` on protocol
- `Packages/AuthFlow/Sources/AuthRepository/` — `AuthAPIClient.deleteAccount`, `NetworkAuthRepository.deleteAccount`
- `Packages/AuthFlow/Sources/AuthFlowProtocol/` — delete use case, settings view model
- `Packages/AuthFlow/Sources/AuthFlowUI/` — register privacy link, settings delete + support + privacy
- Tests in `AuthRepositoryTests`, `AuthFlowProtocolTests`, `AuthFlowUITests`, app composition tests
- **Out of repo:** App Store Connect listing (screenshots, demo account, nutrition labels, export questionnaire) — captured in `design.md` checklist only
- **Dependency:** Backend `POST /v1/auth/delete-account` (hard delete) — already deployed
