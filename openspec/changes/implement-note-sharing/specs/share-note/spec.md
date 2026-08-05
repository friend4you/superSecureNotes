## ADDED Requirements

### Requirement: ShareNoteView share form

`ShareNote` SHALL provide a `ShareNoteView` with a recipient email text field, a Share button, and visible loading and error state bound to `DefaultShareNoteViewModel`. The placeholder-only screen SHALL be replaced.

#### Scenario: Share view shows email field and button

- **WHEN** `ShareNoteView` is rendered
- **THEN** an email text field and a Share button are visible

#### Scenario: Share button disabled while loading

- **WHEN** a share operation is in progress
- **THEN** the Share button is disabled and loading state is shown

### Requirement: ShareNoteViewModel share action

`DefaultShareNoteViewModel` SHALL expose `recipientEmail: String`, `isSharing: Bool`, `errorMessage: String?`, and `share() async`. On share it SHALL: load the note via `NoteRepository.readNote`, reject when `syncState != .synced`, unwrap the FEK with `VaultSession.udk()`, fetch the recipient public key via `VaultRepository.fetchPublicKey(email:)`, wrap the FEK with `wrapFEKForRecipient`, base64-encode the wire blob, and call `NoteRepository.shareNote`. On success it SHALL call `navigator.dismissPresentation()`.

#### Scenario: Successful share dismisses sheet

- **WHEN** `share()` completes successfully
- **THEN** `shareNote` is called with the recipient email and base64 wrapped FEK, and `dismissPresentation()` is invoked

#### Scenario: Unsynced note blocks share

- **WHEN** `share()` is called for a note with `syncState` other than `.synced`
- **THEN** an error message is shown and no share API call is made

#### Scenario: Invalid recipient shows error

- **WHEN** `fetchPublicKey(email:)` fails with `publicKeyNotFound`
- **THEN** an error message is shown and the sheet remains open

### Requirement: ShareNoteDependencies expanded

`ShareNoteDependencyProviding` SHALL require factories backed by `NoteRepository`, `VaultRepository`, and `VaultSessionProtocol` in addition to `Navigating`. `AppComposition` SHALL wire concrete implementations.

#### Scenario: Share view model receives repositories

- **WHEN** `makeShareNoteViewModel(noteID:)` is called from app composition
- **THEN** the returned view model can load notes and fetch recipient public keys
