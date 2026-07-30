## Context

`AuthFlow` provides server account auth (`AuthRepository`), login/register UI, and vault unlock orchestration. `VaultSession` holds UDK and identity private key in memory while active. `RootView` gates navigation on `vaultSession.isActive` — inactive on every cold start because nothing persists across process death.

Prior changes explicitly deferred Keychain persistence, biometrics, and lock policy to a future auth-module slice. This change delivers that slice: persistent credentials, aggressive lock-on-leave, and biometric unlock — without changing `VaultSession` protocol or note storage.

## Goals / Non-Goals

**Goals:**

- Keychain-backed `CredentialStore` for email, refresh token, bio-gated password, vault header cache, bio-enabled flag, and device-setup flag
- Lock immediately on background, lock screen (`protectedDataWillBecomeUnavailable`), and app reopen — clear `VaultSession` and in-memory auth tokens; Keychain unchanged
- Unlock flow: bio first (if enabled) → password fallback with read-only email → online refresh token validation → local vault unlock from cached header → `vaultSession.establish()`
- First launch (`!hasLocalSetup`): internet required; register and login both complete device setup and cache vault header
- Biometric enrollment: offer once after first successful auth (skippable); enable/disable in Settings (enable requires password confirmation)
- Logout: full Keychain wipe + memory clear → first-launch state
- Strict TDD aligned with `development-practices` spec

**Non-Goals:**

- Note blob local cache or offline note sync (separate change)
- Server API changes
- OAuth, social login, account switch without logout
- Auto-refresh while app is unlocked (only on unlock when online)
- Storing access token in Keychain (refresh token only; access token restored in memory on unlock)
- Secure memory zeroing on lock (documented limitation, same as `VaultSession`)

## Decisions

### 1. New targets inside `AuthFlow` package

```
Packages/AuthFlow/
├── Sources/
│   ├── CredentialStoreProtocol/    # NEW — protocol + models
│   ├── CredentialStore/            # NEW — Keychain implementation
│   ├── AuthFlowProtocol/           # extend — UnlockViewModel, LockCoordinator protocol
│   └── AuthFlowUI/                 # extend — UnlockView, bio enrollment, Settings toggle
```

**Rationale:** Keeps all auth-domain code in the `AuthFlow` umbrella. `CredentialStore` is swappable for tests via protocol.

**Alternatives considered:**
- Separate `CredentialStore` package — rejected; too granular for one consumer
- App-target-only Keychain code — rejected; untestable without package extraction

### 2. Keychain item layout

| Item | Access control | Content |
|------|---------------|---------|
| `email` | `whenUnlockedThisDeviceOnly` | User email string |
| `refreshToken` | `whenUnlockedThisDeviceOnly` | Server refresh token |
| `password` | `biometryCurrentSet` + `whenUnlockedThisDeviceOnly` | Vault/login password (only when bio enabled) |
| `vaultHeader` | `whenUnlockedThisDeviceOnly` | Raw vault header `Data` |
| `bioEnabled` | `whenUnlockedThisDeviceOnly` | Bool flag |
| `hasLocalSetup` | `whenUnlockedThisDeviceOnly` | Bool flag |

Password item is created only when user enables biometrics. When bio is disabled, password is never stored — user types it on each unlock.

**Rationale:** `biometryCurrentSet` invalidates stored password when biometrics change. `whenUnlockedThisDeviceOnly` prevents iCloud backup sync of secrets.

### 3. Lock coordinator in app target

`LockCoordinator` lives in `superSecureNotes/` (app layer), not `AuthFlowUI`, because it observes `scenePhase`, `UIApplication.protectedDataWillBecomeUnavailable`, and coordinates `VaultSession.clear()` + auth memory clear.

```swift
// App layer
LockCoordinator(
    vaultSession: vaultSession,
    authRepository: authRepository,
    onLock: { /* navigate to UnlockView */ }
)
```

**Rationale:** Lock policy is app-lifecycle concern. Auth package provides unlock orchestration; app wires lifecycle.

**Alternatives considered:**
- LockCoordinator in AuthFlowUI — couples auth UI to app lifecycle; rejected

### 4. Three root navigation states

```
!hasLocalSetup     → AuthRoute (Login / Register) — internet required
hasLocalSetup && !vaultSession.isActive  → UnlockRoute (locked)
vaultSession.isActive  → NotesRoute
```

`SessionRootNavigation` extended with `hasLocalSetup` and locked state.

**Rationale:** Separates first-time setup from returning-user unlock. Email field only editable during setup.

### 5. Unlock orchestration order

```
1. User presence: bio (if enabled) OR password screen
2. Obtain password (from bio Keychain read or user input)
3. If online: restore refresh token from Keychain → authRepository.refreshSession()
   - success: in-memory AuthSession restored
   - failure: soft error — user re-enters password, retry login with stored email + entered password
4. Read vault header from CredentialStore (local cache)
5. VaultAuthenticator.unlockVault(header, password)
6. vaultSession.establish(keys)
```

Bio/password always required for vault unlock even when refresh succeeds.

**Rationale:** Super-secure model — user presence gate is independent of server session validity. Refresh only re-establishes API access in memory.

### 6. Offline unlock behavior

When offline after step 2:
- Skip step 3 (no server check)
- Proceed with local header + password
- If password was changed on server while offline, local unlock still succeeds with cached password; mismatch discovered when back online (refresh/login fails → soft error, re-enter password)

**Rationale:** Explicit user decision — offline access with potentially stale credentials is acceptable.

### 7. Session restore on `NetworkAuthRepository`

Add `restoreSession(refreshToken:)` or load refresh token from `CredentialStore` inside a new `PersistedAuthRepository` wrapper/adapter that:
- On unlock (online): calls `refreshSession()` using Keychain refresh token
- On lock: clears in-memory `currentSession` / `currentUser` (does not touch Keychain)
- On logout: clears Keychain via `CredentialStore.clearAll()` + memory

**Rationale:** Keeps `NetworkAuthRepository` HTTP logic unchanged; persistence is a composition concern.

### 8. First-launch internet gate

Before login/register submit, check network reachability (`NWPathMonitor` or simple `URLSession` probe). Block with localized error if offline and `!hasLocalSetup`.

**Rationale:** First launch must complete server auth + vault header fetch. Cannot set up device offline.

### 9. Biometric enrollment UX

- After first successful login/register: modal sheet "Enable Face ID?" with Enable / Not Now
- Settings: toggle "Use Face ID" — enabling prompts for password once, stores bio-gated Keychain item; disabling deletes password Keychain item
- On unlock: if bio enabled, `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` fires immediately when locked screen appears

**Rationale:** Offer once respects user choice; Settings allows later opt-in.

### 10. Logout full reset

`CredentialStore.clearAll()` removes all Keychain items. `vaultSession.clear()`. Auth repository memory cleared. Navigation returns to Login with editable email.

Account switch is only via logout — no "use different email" without full reset.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Password in Keychain (even bio-gated) | `biometryCurrentSet` + `whenUnlockedThisDeviceOnly`; document trade-off vs wrapped UDK for v2 |
| Stale password works offline after server change | Accepted; user re-authenticates when online and refresh/login fails |
| Vault header cache out of sync with server | Header changes on password change re-wrap UDK in place — cache updated on successful unlock when online; offline uses cached copy |
| Aggressive lock on every background may frustrate users | Explicit product decision for "super secure"; no grace period in v1 |
| Bio Keychain read fails after OS biometrics change | Fall through to password screen; offer to re-enable bio in Settings |
| `protectedDataWillBecomeUnavailable` timing | Lock coordinator listens to both `scenePhase` and protected-data notifications |

## Migration Plan

1. Ship `CredentialStore` + tests (no app wiring)
2. Wire setup flow to persist credentials after login/register
3. Add lock coordinator + unlock flow
4. Replace cold-start login with unlock for `hasLocalSetup` devices
5. Existing dev installs: treated as `!hasLocalSetup` (no Keychain data) — users log in once to set up

No server migration. No data migration for notes (out of scope).

## Open Questions

None — all decisions captured in explore session.
