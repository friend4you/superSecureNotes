## 1. Production API base URL

- [ ] 1.1 Write failing test: `AppDependencies.apiBaseURL` equals `https://super-secure-notes-api.onrender.com/v1` (`superSecureNotesTests/AppDependenciesTests.swift`)
- [ ] 1.2 Update `AppDependencies.apiBaseURL` to include `/v1` suffix; make test pass

## 2. App Store compliance — Info.plist and target

- [ ] 2.1 Write failing tests or build-setting assertions: Face ID usage key, display name **Super Secure Notes**, iPhone-only device family (`superSecureNotesTests/` or dedicated compliance test)
- [ ] 2.2 Add `INFOPLIST_KEY_NSFaceIDUsageDescription`, `INFOPLIST_KEY_CFBundleDisplayName`, set `TARGETED_DEVICE_FAMILY = 1` on app and test targets in `project.pbxproj`; make tests pass

## 3. Privacy manifest

- [ ] 3.1 Write failing test or resource check: app bundle includes `PrivacyInfo.xcprivacy` with UserDefaults CA92.1
- [ ] 3.2 Add `superSecureNotes/PrivacyInfo.xcprivacy` and wire into app target; make check pass

## 4. App icon flatten

- [ ] 4.1 Replace `AppIcon.appiconset/secure_note_icon.png` with RGB 1024×1024 (no alpha); verify asset catalog accepts it

## 5. AuthRepository delete account — protocol and API client

- [ ] 5.1 Write failing tests: `deleteAccount(password:)` on protocol; API client sends `POST auth/delete-account` with Bearer and password body; maps 401 invalid credentials; rejects empty password (`AuthRepositoryTests/`)
- [ ] 5.2 Add `deleteAccount(password:)` to `AuthRepository` protocol and `NetworkAuthRepository`; implement `AuthAPIClient.deleteAccount`; make tests pass

## 6. Delete account use case

- [ ] 6.1 Write failing tests: success calls repository then invokes reset closure; failure preserves state (`AuthFlowProtocolTests/Domain/DeleteAccountUseCaseTests.swift`)
- [ ] 6.2 Add `DeleteAccountUseCase` and wire through `AuthFlowDependencies`; make tests pass

## 7. Settings UI — delete, privacy, support

- [ ] 7.1 Write failing tests: settings shows delete account (distinct from logout), privacy link, support mailto; delete requires confirmation and password (`AuthFlowUITests/Views/BiometricSettingsViewTests.swift`, view model tests)
- [ ] 7.2 Extend `DefaultBiometricSettingsViewModel` with delete flow; update `BiometricSettingsView` with delete section, privacy link, support link; wire `performLogout` / delete use case from `AppComposition`; make tests pass

## 8. Register UI — privacy link

- [ ] 8.1 Write failing test: `RegisterView` source contains privacy policy link to hosted URL (`AuthFlowUITests/Views/RegisterViewTests.swift`)
- [ ] 8.2 Add privacy link section to `RegisterView`; add localized strings; make test pass

## 9. Session lock integration

- [ ] 9.1 Write failing test: successful delete invokes same reset path as logout (`superSecureNotesTests/` or `AuthFlowProtocolTests`)
- [ ] 9.2 Ensure delete use case calls `LogoutReset.perform` (or shared reset) only after API success; make test pass

## 10. Integration verification

- [ ] 10.1 Run `AuthFlow`, `AuthRepository`, and app test targets; fix regressions
- [ ] 10.2 Manual smoke on device: register → create note → delete account → confirm login screen and server account removed

## 11. Release archive checklist (manual)

- [ ] 11.1 Archive Release scheme; confirm no `-UseStubBackend` in Profile/Archive
- [ ] 11.2 Validate 1024 icon and Face ID string in archived app Info.plist
- [ ] 11.3 Complete App Store Connect checklist from `design.md`
