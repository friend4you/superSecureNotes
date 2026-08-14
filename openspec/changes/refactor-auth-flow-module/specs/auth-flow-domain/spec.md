## ADDED Requirements

### Requirement: AuthFlowDomainProtocol package target

The `AuthFlow` package SHALL expose a library product `AuthFlowDomainProtocol` backed by a target containing protocol definitions for auth use cases, shared result types, and `EstablishVaultSessionPolicy`. The target SHALL depend on `AuthRepositoryProtocol`, `CredentialStoreProtocol`, `VaultRepositoryProtocol`, `VaultSessionProtocol`, `NoteRepositoryProtocol`, and `NetworkProtocol`. It SHALL NOT import SwiftUI.

#### Scenario: AuthFlowDomainProtocol builds without SwiftUI

- **WHEN** the `AuthFlowDomainProtocol` target is built
- **THEN** it compiles without importing SwiftUI

#### Scenario: Use case protocols are public

- **WHEN** a consumer imports `AuthFlowDomainProtocol`
- **THEN** `LoginUseCase`, `RegisterUseCase`, `UnlockUseCase`, `EstablishVaultSessionUseCase`, `BiometricUnlockUseCase`, and `RestoreOnlineSessionUseCase` protocol types are accessible

### Requirement: AuthFlowDomain package target

The `AuthFlow` package SHALL expose a library product `AuthFlowDomain` backed by a target that depends on `AuthFlowDomainProtocol` and provides default implementations: `DefaultLoginUseCase`, `DefaultRegisterUseCase`, `DefaultUnlockUseCase`, `DefaultEstablishVaultSessionUseCase`, `DefaultBiometricUnlockUseCase`, and `DefaultRestoreOnlineSessionUseCase`.

#### Scenario: AuthFlowDomain builds with default use cases

- **WHEN** the `AuthFlowDomain` target is built
- **THEN** all `Default*` use case types compile and conform to their protocols

### Requirement: EstablishVaultSessionUseCase

`AuthFlowDomainProtocol` SHALL define `EstablishVaultSessionPolicy` with cases covering login's remote-header branch, post-create/register unlock, and standard unlock. `EstablishVaultSessionUseCase` SHALL unlock the vault with provided header data and password, open the notes index store, establish the vault session, and for the `firstLoginWithRemoteHeader` policy SHALL pull remote notes catalogs before establishing. Failures during notes index open SHALL clear the vault session before propagating the error.

#### Scenario: Standard unlock establishes session and opens index

- **WHEN** `execute` is called with `standardUnlock` policy, valid header data, and password
- **THEN** `vaultAuthenticator.unlockVault` is called, `vaultSession.establish` is called, and `notesIndexStore.open` is called with a UDK-derived passphrase

#### Scenario: First login with remote header pulls catalogs

- **WHEN** `execute` is called with `firstLoginWithRemoteHeader` policy and remote header was pulled
- **THEN** `noteSync.pullRemoteNotesCatalog` and `noteSync.pullRemoteSharedCatalog` are called before `vaultSession.establish`

#### Scenario: Index open failure clears vault session

- **WHEN** `notesIndexStore.open` throws after `vaultSession.establish` began
- **THEN** `vaultSession.clear` is called before the error propagates

### Requirement: LoginUseCase

`LoginUseCase` SHALL validate non-empty email and password, reject first-time setup when offline, call `authRepository.login`, resolve vault header (pull if local missing), call `EstablishVaultSessionUseCase` with the appropriate policy, save setup via `credentialStore.saveSetup`, and return a result containing `wasFirstSetup: Bool`. It SHALL map `AuthRepositoryError` and `VaultRepositoryError` to `AuthFlowError`.

#### Scenario: Login rejects empty credentials

- **WHEN** `execute` is called with empty email or password
- **THEN** it throws or returns `AuthFlowError.validationError` without calling `authRepository.login`

#### Scenario: Login rejects offline first setup

- **WHEN** `credentialStore.hasLocalSetup` is `false` and `networkReachability.isOnline` is `false`
- **THEN** it returns `AuthFlowError.networkRequired` without calling `authRepository.login`

#### Scenario: Login returns wasFirstSetup on first device setup

- **WHEN** login succeeds and `credentialStore.hasLocalSetup` was `false` before save
- **THEN** the result has `wasFirstSetup` equal to `true`

#### Scenario: Login maps invalid credentials

- **WHEN** `authRepository.login` throws `AuthRepositoryError.invalidCredentials`
- **THEN** the use case surfaces `AuthFlowError.invalidCredentials`

### Requirement: RegisterUseCase

`RegisterUseCase` SHALL validate non-empty email and password, reject first-time setup when offline, call `authRepository.register`, create vault via `vaultAuthenticator`, write and upload header, call `EstablishVaultSessionUseCase` with post-create policy, save setup, and return `wasFirstSetup`. On header upload failure it SHALL clear the auth session before surfacing the error.

#### Scenario: Register rejects empty credentials

- **WHEN** `execute` is called with empty email or password
- **THEN** it surfaces `AuthFlowError.validationError` without calling `authRepository.register`

#### Scenario: Register uploads vault header after creation

- **WHEN** registration and vault creation succeed
- **THEN** `noteSync.uploadVaultHeaderOrThrow` is called with the new header data

#### Scenario: Register clears session on upload failure

- **WHEN** vault header upload throws
- **THEN** `authRepository.clearSession` is called before the error propagates

#### Scenario: Register returns wasFirstSetup on first device setup

- **WHEN** registration succeeds and `credentialStore.hasLocalSetup` was `false` before save
- **THEN** the result has `wasFirstSetup` equal to `true`

### Requirement: UnlockUseCase

`UnlockUseCase` SHALL optionally restore online session when reachable, unlock vault from stored header, call `EstablishVaultSessionUseCase` with standard policy, and flush pending note sync when online.

#### Scenario: Unlock restores online session when online

- **WHEN** `execute` is called with password and network is online
- **THEN** `RestoreOnlineSessionUseCase` is invoked before vault unlock

#### Scenario: Unlock flushes pending sync when online

- **WHEN** vault unlock and session establishment succeed while online
- **THEN** `noteSync.flushPending` is called

#### Scenario: Unlock surfaces vault unlock failure

- **WHEN** `vaultAuthenticator.unlockVault` throws
- **THEN** the use case surfaces `AuthFlowError.vaultUnlockFailed`

### Requirement: BiometricUnlockUseCase

`BiometricUnlockUseCase` SHALL evaluate biometrics when enabled and available, load the password from the credential store on success, and return a result enum distinguishing success, cancelled, failed, unavailable, and disabled/skipped paths.

#### Scenario: Biometric success returns password

- **WHEN** biometrics are enabled, evaluation succeeds, and credential load succeeds
- **THEN** the result is success with the stored password

#### Scenario: Biometric unavailable falls back

- **WHEN** biometrics are disabled or `canEvaluateBiometrics` is `false`
- **THEN** the result indicates password entry is required without prompting

#### Scenario: Biometric cancelled falls back

- **WHEN** the user cancels biometric authentication
- **THEN** the result indicates password entry is required

### Requirement: RestoreOnlineSessionUseCase

`RestoreOnlineSessionUseCase` SHALL attempt session restore via refresh token. On non-network restore failures it SHALL retry `authRepository.login` with provided credentials. Network errors during restore or retry SHALL be ignored (offline continuation).

#### Scenario: Restore succeeds with refresh token

- **WHEN** `AuthSessionRestoreHelper.restoreSession` succeeds
- **THEN** no login retry is performed

#### Scenario: Restore failure retries login

- **WHEN** restore throws a non-network `AuthRepositoryError`
- **THEN** `authRepository.login` is called with the provided credentials

#### Scenario: Network error during restore is ignored

- **WHEN** restore throws `AuthRepositoryError.networkError`
- **THEN** the use case completes without throwing

### Requirement: AuthFlowProtocol depends on domain protocols

`AuthFlowProtocol` SHALL depend on `AuthFlowDomainProtocol`. `DefaultLoginViewModel`, `DefaultRegisterViewModel`, and `DefaultUnlockViewModel` SHALL accept use case protocols via initializer injection instead of orchestrating repository calls directly.

#### Scenario: Login view model uses LoginUseCase

- **WHEN** `DefaultLoginViewModel.login` is called
- **THEN** it delegates to `LoginUseCase` and maps the result to `state`

#### Scenario: Register view model uses RegisterUseCase

- **WHEN** `DefaultRegisterViewModel.register` is called
- **THEN** it delegates to `RegisterUseCase` and maps the result to `state`

#### Scenario: Unlock view model uses UnlockUseCase and BiometricUnlockUseCase

- **WHEN** `DefaultUnlockViewModel.unlockWithPassword` or biometric retry is called
- **THEN** it delegates to the corresponding use case protocols
