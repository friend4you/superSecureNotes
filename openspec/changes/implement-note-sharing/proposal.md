## Why

`ShareNote` is scaffolded and reachable from `NotesFlow`, but sharing is still a no-op: no recipient lookup, no FEK wrapping for another user's public key, and no way to view notes shared with the current user. The backend now exposes sharing and `GET /v1/users/public-key?email=` — the client can implement end-to-end share grants and a read-only shared-notes journey.

## What Changes

- Add asymmetric recipient FEK wrap/unwrap in `SecureCrypto` (X25519 + HKDF + existing ChaChaPoly key wrap)
- Extend `VaultRepository` with `fetchPublicKey(email:)` calling `GET /v1/users/public-key?email=`
- Extend `NoteRepository` with `shareNote(noteID:recipientEmail:wrappedFEK:)`, `listSharedNotes()`, and `readSharedNote(noteID:)`
- Replace `ShareNoteView` placeholder with email field + Share button; orchestrate load FEK → fetch recipient public key → wrap → POST share
- Add segmented control on note list (`My Notes` | `Shared`) and load `GET /v1/notes/shared` for the Shared segment
- Add read-only shared note detail: owner email, title, body, attachments view-only; no Save/Delete/Share toolbar actions
- Extend `NotesRoute` with `sharedDetail(noteID:)` to separate owned vs shared detail behavior
- Wire new dependencies through `ShareNoteDependencies`, `NotesFlowDependencies`, and `AppComposition`
- Block share when note is not synced (recipient needs server blob)
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

- `share-note`: Share screen UI, view model orchestration, and dependency wiring for posting share grants
- `vault-repository`: Email-based identity public key lookup for share recipients

### Modified Capabilities

- `secure-crypto`: Recipient FEK wrap and shared-grant FEK unwrap using vault identity keys
- `note-repository`: Sharing REST client methods and protocol surface for share/list/read shared notes
- `notes-flow`: Segmented owned/shared list, shared note read-only detail screen and navigation
- `app-navigation`: App composition wires vault repository and sharing deps into ShareNote and NotesFlow

## Impact

- `Packages/SecureCrypto/` — new share FEK wrap/unwrap APIs and tests
- `Packages/VaultRepository/` — `fetchPublicKey(email:)`, API client, protocol extension
- `Packages/NoteRepository/` — sharing models, API client, `NetworkNoteRepository` methods; stub no-ops in local repo
- `Packages/ShareNote/` — real share UI and view model; expanded `ShareNoteDependencies`
- `Packages/NotesFlow/` + `Packages/NotesFlowRoutes/` — segmented list, `SharedNoteDetailView`, `NotesRoute.sharedDetail`
- `superSecureNotes/AppComposition.swift` — dependency wiring
- Out of scope: revoke share UI, outgoing recipient list on owned note detail, editing shared notes, local persistence of shared notes, stub-backend share simulation
