## Context

App Store review flagged gaps from a local audit: missing Face ID usage string, no privacy manifest, RGBA marketing icon, iPad target without iPad UI, localhost-era base URL shape, and no in-app account deletion despite registration. Backend deletion is live at `POST /v1/auth/delete-account` (Bearer + password, hard delete). Privacy policy is hosted at `https://super-secure-notes-api.onrender.com/privacy`. Support is email-only for v1.

Current auth stack: `NetworkAuthRepository` + `AuthAPIClient` with paths relative to `AppDependencies.apiBaseURL`. Settings is `BiometricSettingsView` with biometric toggle and logout. Logout uses `LogoutReset.perform` from app composition.

## Goals / Non-Goals

**Goals:**

- Pass App Store binary validation and guideline 5.1.1(v) account deletion
- iPhone-only v1 with display name **Super Secure Notes**
- Wire production API at `https://super-secure-notes-api.onrender.com/v1`
- In-app privacy and support links; delete account with password confirmation

**Non-Goals:**

- Terms of Service link (follow-up change)
- Recovery mnemonic display UI
- iPad layout or screenshots
- Visual redesign / marketing polish beyond icon flattening
- App Store Connect listing assets (checklist below, manual)
- UGC report/block for note sharing
- Lowering iOS 26.2 deployment target

## Decisions

### 1. Single change, iOS-only scope

All client-side release blockers ship in one change. Backend deletion endpoint is treated as an external dependency already satisfied.

**Alternative:** Split compliance vs account deletion — rejected; both are required before first submission.

### 2. Delete account flow

```
Settings → Delete Account → Alert confirm → Password field → POST delete-account
  → success: LogoutReset.perform (same as logout + server account gone)
  → failure: show error, keep local data
```

Password is required by the API and serves as re-authentication. Use a dedicated `DeleteAccountUseCase` rather than overloading logout.

**Alternative:** Web-only deletion URL — rejected; Apple requires in-app initiation when registration is in-app.

### 3. API base URL shape

`AppDependencies.apiBaseURL = https://super-secure-notes-api.onrender.com/v1`

All clients keep appending `auth/...`, `notes/...` without a `v1/` prefix in path strings. Update `AppDependenciesTests` accordingly.

### 4. Legal link constants

Centralize URLs in the app target or AuthFlowUI constants:

| Constant | Value |
|---|---|
| Privacy | `https://super-secure-notes-api.onrender.com/privacy` |
| Support | `mailto:vlad.arsenyuk@gmail.com` |

Register gets privacy only. Settings gets privacy + support. Terms deferred.

### 5. App Store compliance implementation

| Item | Approach |
|---|---|
| Face ID | `INFOPLIST_KEY_NSFaceIDUsageDescription` = "Unlock your encrypted notes." |
| Privacy manifest | `superSecureNotes/PrivacyInfo.xcprivacy` with UserDefaults CA92.1 |
| Display name | `INFOPLIST_KEY_CFBundleDisplayName` = Super Secure Notes |
| iPhone only | `TARGETED_DEVICE_FAMILY = 1` on app + test targets |
| Icon | Re-export 1024 PNG as RGB, replace `secure_note_icon.png` |
| Encryption | Do not add `ITSAppUsesNonExemptEncryption = NO`; answer Connect questionnaire manually |

### 6. SQLCipher third-party manifest

Verify resolved `SQLCipher.swift` package includes its own `PrivacyInfo.xcprivacy`. If missing at resolve time, upgrade dependency or document in review notes. Not a user-facing requirement.

## Risks / Trade-offs

- **[Wrong password on delete]** → Map `invalid_credentials`; do not wipe locally
- **[Network failure mid-delete]** → Server may or may not have deleted; user sees error; safe to retry or contact support
- **[No Terms of Service]** → Low risk for v1 with privacy link; add before scale if Apple asks
- **[Render cold start]** → Review demo account may hit slow first request; note in App Review Information
- **[Recovery mnemonic hidden]** → Users who lose password have no in-app recovery; accurate App Store copy must not claim recovery until UI ships

## Migration Plan

1. Implement and test on device (Face ID, delete flow against production API)
2. Archive Release build; validate icon and plist in Organizer
3. Complete App Store Connect checklist (below)
4. Submit with demo credentials in App Review Information

**Rollback:** Revert change; no server migration needed (deletion API already live).

## App Store Connect checklist (manual, out of spec)

- [ ] Privacy Policy URL: `https://super-secure-notes-api.onrender.com/privacy`
- [ ] Support URL or support page (mailto alone may not satisfy Connect — consider a simple landing page)
- [ ] Demo account email/password with sample notes
- [ ] App Privacy nutrition labels: Email, User Content (notes, photos), encrypted on device
- [ ] Export compliance questionnaire: Yes, uses encryption beyond HTTPS
- [ ] iPhone screenshots (6.7", 6.5", etc.)
- [ ] Age rating questionnaire
- [ ] Category: Productivity
- [ ] Review notes: Face ID optional, sharing is private encrypted 1:1, no public UGC feed

## Open Questions

- None blocking implementation. Terms of Service deferred to follow-up change.
