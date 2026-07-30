## Why

superSecureNotes currently requires full email + password login on every cold start because auth tokens, vault keys, and vault header are held in memory only. Users expect a secure-notes app to unlock quickly with biometrics while staying locked whenever they leave the app — and to work offline after initial setup. This change adds persistent credentials, aggressive lock policy, and biometric unlock on top of the existing two-layer auth model (server session + vault unlock).

## What Changes

- Add `CredentialStore` — Keychain-backed persistence for email, refresh token, bio-gated password, vault header cache, and device-setup flag
- Add `LockCoordinator` — lock immediately on background, lock screen, and app reopen; clear in-memory `VaultSession` and auth tokens; leave Keychain untouched
- Add `UnlockFlow` — bio-first unlock (if enabled), password-only fallback with read-only email, online token refresh after user presence, local vault unlock from cached header
- Add `UnlockView` — locked-state UI (bio prompt + password screen with email locked)
- Add biometric enrollment — offer once after first successful login/register; enable/disable later in Settings (enable requires password confirmation)
- Update first-launch flow — internet required when `!hasLocalSetup`; register and login both complete device setup
- Update logout — full reset (wipe Keychain + memory, return to first-launch login)
- Update `NetworkAuthRepository` (or adapter) — restore session from Keychain refresh token on unlock when online
- Update app root navigation — three states: first launch (auth), locked (unlock), unlocked (notes)

## Capabilities

### New Capabilities

- `credential-store`: Keychain persistence for credentials, vault header cache, bio-gated password, and device-setup state
- `session-lock`: Aggressive lock policy, lock coordinator, and in-memory session clearing on lock
- `biometric-unlock`: Biometric enrollment, unlock flow, unlock UI, and Settings toggle

### Modified Capabilities

<!-- No existing main specs in openspec/specs/ for auth modules yet; deltas captured in new capability specs that reference existing packages -->

## Impact

- `Packages/AuthFlow/` — new targets or modules: `CredentialStore`, lock/unlock orchestration, `UnlockView`, Settings bio toggle
- `Packages/AuthFlow/Sources/AuthRepository/` — session restore from persisted refresh token
- `superSecureNotes/` — `RootView`, `SessionRootNavigation`, `AppComposition` wiring for lock/unlock lifecycle
- `Packages/VaultSession/` — no protocol changes; auth module continues as sole writer of `establish` / `clear`
- Out of scope: note blob local cache, note sync offline, server API changes, OAuth, account switch without logout
