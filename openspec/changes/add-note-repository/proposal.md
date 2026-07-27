## Why

superSecureNotes needs server-backed note storage before multi-device note sync and a real note list UI can work. `SecureCrypto` defines the `.note` binary format and encryption primitives, and `VaultRepository` handles `vault.meta` sync, but nothing persists or fetches encrypted note blobs from a backend. A dedicated repository with a protocol/implementation split — mirroring `VaultRepository` — gives `NotesFlow` and future note-editing modules a stable contract while the backend is still being built.

## What Changes

- Add a new Swift Package `NoteRepository` with two library products: `NoteRepositoryProtocol` (contracts and shared types) and `NoteRepository` (network implementation)
- Define `NoteRepository` protocol with `listNotes()`, `readNote(noteID:)`, `writeNote(noteID:data:)`, and `deleteNote(noteID:)`
- Define `NoteSummary` model for server-indexed plaintext metadata (note ID, title, updated timestamp)
- Define `NoteRepositoryError` with typed error cases including `noteNotFound`
- Reuse `AccessTokenProviding` from `VaultRepositoryProtocol` for injected bearer-token auth
- Implement `NetworkNoteRepository` actor using internal `URLSession` HTTP client (not exposed as a public protocol)
- Define a v1 REST API contract for note list, upload/download, and delete — shared contract for Swift client and future backend
- Repository deals in raw `Data` for note blobs; `NoteMetadata` parse/serialize stays in `SecureCrypto` callers
- Server indexes plaintext header fields from uploaded `.note` blobs for list responses (mirrors vault public-key indexing)
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

- `note-repository`: Server-backed note blob persistence and indexed note listing — package boundary, protocol models, token provider injection, network implementation, proposed REST API contract

### Modified Capabilities

<!-- No existing main specs to modify -->

## Impact

- `Packages/NoteRepository/` — new package (`NoteRepositoryProtocol` + `NoteRepository` targets)
- `Packages/NoteRepository/` — depends on `VaultRepositoryProtocol` for `AccessTokenProviding`
- `superSecureNotes.xcodeproj` — link products (no app wiring until note data layer is integrated)
- Future backend — implement endpoints defined in `design.md` REST contract
- Out of scope: local file storage, note encryption/decrypt orchestration, `SecureCrypto` / `VaultSession` integration, sharing endpoints, conflict resolution / ETags, SwiftUI screens
