## Context

First-time login/register establishes the vault session inside `LoginUseCase` / `RegisterUseCase` before returning to the view model. `RootView` listens to `vaultSession.changes` and calls `SessionRootNavigation.apply`, which invokes `navigator.setRoot(NotesRoute.list)` when the vault is active.

`NavigationRouter.setRoot` clears `presentedRoute`, wiping any enrollment sheet presented via `navigator.present(AuthRoute.biometricEnrollment, style: .sheet)`. Whether enrollment survives depends on async scheduling — a race, not deterministic behavior.

Enabling biometrics requires storing the vault plaintext password in a bio-gated Keychain item (`CredentialStore.savePassword`). The app discards the password after vault establishment today, forcing re-entry on Settings and enrollment screens.

Prior spec (`add-session-persistence/specs/biometric-unlock`) requires password confirmation on Settings enable and does not address the navigation race.

## Goals / Non-Goals

**Goals:**

- Enrollment sheet always appears on first setup (login/register) and survives vault-active root sync
- After skip/enable, navigate to notes reliably
- Pending enrollment survives app kill (UserDefaults) and resumes after unlock if interrupted
- Settings biometric toggle works without password re-entry while vault session is active
- Enrollment on first setup does not re-ask for password when available from login/register
- Session password cache cleared on lock and logout; never persisted to UserDefaults or Keychain except via explicit bio enable
- Strict TDD aligned with `development-practices` spec

**Non-Goals:**

- Storing password in UserDefaults or on disk outside bio-gated Keychain
- Changing bio-first unlock behavior, Keychain access control, or vault crypto
- Re-showing enrollment after user explicitly skipped (flag cleared on skip)
- Proactive enrollment prompts on repeat login when flag is clear

## Decisions

### 1. `SessionPasswordCache` — in-memory, `@MainActor`

```swift
@MainActor
protocol SessionPasswordCaching: AnyObject {
    func store(_ password: String)
    func password() -> String?
    func clear()
}
```

Populated by `LoginUseCase`, `RegisterUseCase`, and `UnlockUseCase` immediately after successful `establishVaultSession`. Cleared by `LockCoordinator.lock()` and `LogoutReset.perform` (before or alongside vault clear).

**Rationale:** Password managers commonly hold the master password in memory while unlocked. Required for Settings toggle and enrollment without re-prompt.

**Alternatives considered:**
- Keychain without bio gate during session — rejected; unnecessary persistence risk
- Pass password through view model only — rejected; Settings and enrollment are decoupled from login VM after navigation

### 2. `PendingBiometricEnrollmentStore` — UserDefaults boolean

```swift
protocol PendingBiometricEnrollmentStoring {
    var isPending: Bool { get }
    func setPending(_ pending: Bool)
}
```

Implementation uses `UserDefaults` key e.g. `pendingBiometricEnrollment`. Set `true` when first setup completes (`wasFirstSetup == true`) before presenting enrollment. Cleared on skip or successful enable in `DefaultBiometricEnrollmentViewModel`.

**Not** cleared on lock — user may background mid-enrollment; flag remains until explicit skip/enable.

**Rationale:** Survives app kill; non-sensitive boolean; user explicitly chose not to require Keychain for this flag.

### 3. Gate `SessionRootNavigation` on pending enrollment

Extend `SessionRootNavigation.apply`:

```
if isVaultActive && !pendingEnrollment {
    setRoot(notes)
} else if isVaultActive && pendingEnrollment {
    // do NOT setRoot(notes) — stay on current auth root (login/register)
} else if hasLocalSetup {
    setRoot(unlock)
} else {
    setRoot(login)
}
```

When vault becomes active during pending enrollment, root stays on login/register. Login/register view model presents enrollment sheet on top.

After enrollment completes (skip/enable):
1. Clear pending flag
2. Call `SessionRootNavigation.apply(hasLocalSetup: true, isVaultActive: true, pendingEnrollment: false, ...)` → notes root

**Rationale:** Fixes race without deferring vault establishment. Vault can be active while UI remains on auth stack under sheet.

**Alternatives considered:**
- Present enrollment after notes root (Option 2 from exploration) — rejected; user chose Option 1
- Defer vault establishment until enrollment — rejected; larger behavioral change

### 4. Enrollment completion triggers notes navigation

`DefaultBiometricEnrollmentViewModel` on skip/enable:
1. Clear pending flag
2. `navigator.dismissPresentation()`
3. Notify composition to re-sync root → notes (via callback, `NotificationCenter`, or direct `SessionRootNavigation.apply` injection)

Prefer injecting a small `EnrollmentCompletionHandler` or reusing existing root sync path in `AppComposition` rather than hard-coding notes route in AuthFlow domain.

### 5. Resume enrollment after unlock when pending

When user unlocks and `pendingBiometricEnrollment == true`:
- After successful unlock, present enrollment sheet (same route) before allowing notes root
- Session cache repopulated by `UnlockUseCase` during unlock — enrollment enable can proceed without password field

Edge case: lock during enrollment clears session cache. User must unlock again; cache repopulated; enrollment still pending; sheet shown again.

### 6. Enrollment UI — no password field when cache available

`BiometricEnrollmentViewModel.enableBiometrics()` reads password from `SessionPasswordCache`. If nil, surface error or fall back to password field (edge case only — first setup should always have cache).

Login/register view models pass nothing extra — cache is populated by use case before enrollment presents.

Remove password `SecureField` from `BiometricEnrollmentView` when cache has password (always on first setup path).

### 7. Settings enable via cache

`DefaultBiometricSettingsViewModel.enableBiometrics()`:
- If `sessionPasswordCache.password()` non-nil → `setBioEnabled(true)` + `savePassword(cached)` without UI prompt
- If nil → existing `requiresPasswordConfirmation` fallback (user unlocked via bio-only path or cache cleared)

Remove always-visible password field; show SecureField only on fallback path.

**Spec change:** Replaces "Enabling SHALL require the user to enter their password once" with "SHALL use session cache when available; otherwise require password entry."

### 8. Login/register set pending before present

Order in view model after use case success:
1. Use case already saved setup and established vault (cache populated)
2. If `wasFirstSetup`: `pendingStore.setPending(true)` then `present(biometricEnrollment)`
3. Root sync sees pending → does not navigate to notes

Enrollment VM clears pending on skip/enable → root sync navigates to notes.

## Risks / Trade-offs

- **[Risk] Password in memory while unlocked** → Mitigation: clear on lock/logout; never log; single shared cache instance in app composition
- **[Risk] User stays on login screen with active vault** → Mitigation: sheet overlay; brief transition to notes after dismiss; acceptable per user decision
- **[Risk] Pending flag stuck true if enrollment VM crashes before clear** → Mitigation: enable/skip always clear; integration test; user can still enable from Settings
- **[Risk] `setRoot` still races if pending set after vault change fires** → Mitigation: set pending synchronously in view model before await completes root observer; or set pending inside use case before establish returns
- **[Trade-off] UserDefaults for pending flag** → acceptable for non-secret UX state; simpler than Keychain

## Migration Plan

1. Add cache + pending store protocols and default implementations
2. Wire into use cases and composition (tests first)
3. Update `SessionRootNavigation` + `RootView` sync
4. Update enrollment and settings view models + views
5. Integration tests for race and resume paths

No data migration. Existing users without pending flag unaffected. Rollback: revert package commit.

## Open Questions

None — decisions confirmed in exploration.
