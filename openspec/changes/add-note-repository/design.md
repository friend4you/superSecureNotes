## Context

`SecureCrypto` handles stateless note crypto: `.note` binary format, FEK wrap/unwrap, payload encrypt/decrypt, and `NoteMetadata` parsing from plaintext headers. `VaultRepository` provides server-backed `vault.meta` sync and public-key lookup. `NotesFlow` currently provides UI scaffolding only — no note data loading or persistence.

The `add-vault-repository` design explicitly deferred note file sync (`<uuid>.note` blobs). Multi-device note sync and a real note list require:

1. Uploading/downloading encrypted `.note` blobs to a backend
2. Listing the user's notes without downloading every blob (server indexes plaintext header metadata)

No backend exists yet. This change defines the Swift repository and REST API contract — same pattern as `add-vault-repository`.

## Goals / Non-Goals

**Goals:**

- New Swift Package `Packages/NoteRepository/` with `NoteRepositoryProtocol` and `NoteRepository` targets
- `NoteRepository` protocol: `listNotes()`, `readNote(noteID:)`, `writeNote(noteID:data:)`, `deleteNote(noteID:)`
- `NoteSummary` model for list responses (note ID, title, updated timestamp)
- `NoteRepositoryError` typed errors
- Reuse `AccessTokenProviding` from `VaultRepositoryProtocol` for bearer-token auth
- `NetworkNoteRepository` actor with internal `URLSession` HTTP client
- Repository boundary uses raw `Data` for note blobs; callers parse via `SecureCrypto`
- Server indexes plaintext metadata from uploaded `.note` headers for list endpoint
- Proposed v1 REST API for backend development
- Strict TDD aligned with `development-practices` spec

**Non-Goals:**

- Local file storage or offline fallback
- Note encryption/decryption orchestration or `VaultSession` integration
- `SecureCrypto` changes
- Sharing endpoints (`POST /notes/{id}/share`) — deferred to `ShareNote`
- Conflict resolution / ETags on note upload (last-write-wins in v1)
- SwiftUI screens or `NotesFlow` wiring
- `FileNoteRepository` stub (future `add-debug-stub-backend` extension or separate change)

## Decisions

### 1. Package name: `NoteRepository`

```
Packages/NoteRepository/
├── Package.swift
├── Sources/
│   ├── NoteRepositoryProtocol/
│   │   ├── NoteRepository.swift
│   │   ├── NoteRepositoryError.swift
│   │   └── Models/NoteSummary.swift
│   └── NoteRepository/
│       ├── NetworkNoteRepository.swift
│       └── Internal/
│           ├── NoteAPIClient.swift
│           └── NoteResponseDTO.swift
└── Tests/
    ├── NoteRepositoryProtocolTests/
    └── NoteRepositoryTests/
```

**Rationale:** Mirrors `VaultRepository` naming. User chose repository pattern in exploration.

**Alternatives considered:**
- `NotesRepository` — rejected; singular matches `VaultRepository`, `AuthRepository`
- Single target — rejected; protocol/impl split matches project convention

### 2. Protocol module has zero networking dependencies (except token provider)

`NoteRepositoryProtocol` imports Foundation only for its own types. `AccessTokenProviding` is imported from `VaultRepositoryProtocol` in the `NoteRepository` implementation target only — the protocol module does NOT depend on `VaultRepositoryProtocol`.

Wait — the proposal says reuse AccessTokenProviding. Let me think about where it lives:

Option A: NoteRepositoryProtocol depends on VaultRepositoryProtocol for AccessTokenProviding
Option B: NetworkNoteRepository takes AccessTokenProviding but protocol module doesn't reference it

Actually VaultRepository has AccessTokenProviding IN VaultRepositoryProtocol. For NoteRepository, NetworkNoteRepository needs token provider. The protocol module doesn't need to define AccessTokenProviding — only NetworkNoteRepository init needs it.

So:
- NoteRepositoryProtocol: NoteRepository, NoteSummary, NoteRepositoryError (Foundation only)
- NoteRepository: depends on NoteRepositoryProtocol + VaultRepositoryProtocol (for AccessTokenProviding)

This matches how consumers wire things — they already have AuthRepositoryAccessTokenProvider from VaultRepositoryProtocol.

### 3. `actor NetworkNoteRepository` as default implementation

```swift
public struct NoteSummary: Equatable, Sendable {
    public let noteID: UUID
    public let title: String
    public let updatedAt: UInt64  // epoch seconds, matches NoteMetadata
}

public protocol NoteRepository: Sendable {
    func listNotes() async throws -> [NoteSummary]
    func readNote(noteID: UUID) async throws -> Data
    func writeNote(noteID: UUID, data: Data) async throws
    func deleteNote(noteID: UUID) async throws
}
```

`NetworkNoteRepository` init: `baseURL: URL`, `tokenProvider: any AccessTokenProviding`, `session: URLSession = .shared`.

**Rationale:** Actor serializes concurrent requests. Token provider decouples from `AuthRepository`. `NoteSummary` is an API contract type, not `SecureCrypto.NoteMetadata`.

**Alternatives considered:**
- List returns only `[UUID]` — rejected; requires N downloads for note list UI
- Include `NoteMetadata` from SecureCrypto in protocol — rejected; creates crypto dependency

### 4. Raw `Data` for note blob I/O

Repository returns/stores opaque `.note` bytes. No `NoteMetadata` or `NoteFileSections` in protocol module.

**Rationale:** `NoteMetadata` lives in `SecureCrypto`. Keeps `NoteRepositoryProtocol` free of crypto dependencies.

### 5. One note collection per authenticated account

API paths are scoped to the authenticated user. No `vaultId` or collection ID parameter.

**Rationale:** Current product model is one vault per account, notes belong to that vault.

### 6. Server indexes plaintext metadata from `.note` header

On `PUT /notes/{noteId}`, the server:

1. Stores the full `.note` blob privately for the authenticated user
2. Parses the SSNT v1 plaintext header to extract `note_id`, `title`, and `updated_at` for the list index

`GET /notes` returns indexed metadata — never the encrypted payload or wrapped FEK.

**Rationale:** Enables note list UI without downloading every blob. Mirrors vault public-key indexing from `vault.meta`.

**Alternatives considered:**
- Dumb blob storage with ID-only list — rejected; poor UX for note list
- Separate metadata endpoint — rejected; duplicates data already in header

### 7. Note ID in URL must match blob header

`writeNote(noteID:data:)` validates locally that the `noteID` path parameter matches the `note_id` parsed from the blob header (via a minimal header parse in the repository, OR client responsibility).

Actually — vault repository doesn't parse headers. For note ID mismatch, two options:
- Client responsibility only (like vault)
- Server validates on PUT and returns 400

For v1, **server validates** on PUT; client validates locally with `guard !data.isEmpty` only. Mismatch is a server `validation_error`. Keeps repository free of SecureCrypto.

**Rationale:** Fail fast at server; repository stays opaque-byte focused.

### 8. Client-side validation

- `writeNote`: reject empty `Data` locally with `validationError`
- `readNote` / `deleteNote`: no empty UUID check needed (UUID type is always valid)
- `writeNote`: reject if `noteID` is nil UUID? Probably not needed.

### 9. Proposed v1 REST API contract

Base URL: configurable at `NetworkNoteRepository` init (e.g. `https://api.supersecurenotes.example/v1`).

All endpoints require `Authorization: Bearer <accessToken>` from `AccessTokenProviding`.

#### GET `/notes`

Response `200 OK`:
```json
[
  {
    "noteId": "<uuid>",
    "title": "My note",
    "updatedAt": 1700000000
  }
]
```

Empty array if user has no notes.

Errors:
- `401` — `notAuthenticated`

#### GET `/notes/{noteId}`

Path parameter `noteId`: UUID string.

Response `200 OK`:
- Body: raw binary `.note` (`Content-Type: application/octet-stream`)

Errors:
- `401` — `notAuthenticated`
- `404` — `note_not_found` → `NoteRepositoryError.noteNotFound`

#### PUT `/notes/{noteId}`

Request:
- Body: raw binary `.note` (`Content-Type: application/octet-stream`)

Response `204 No Content` on success.

Server side-effect: extract and index plaintext metadata from SSNT v1 header.

Errors:
- `401` — `notAuthenticated`
- `400` — invalid blob or note ID mismatch → `validationError`

#### DELETE `/notes/{noteId}`

Response `204 No Content` on success.

Errors:
- `401` — `notAuthenticated`
- `404` — `note_not_found` → `noteNotFound`

#### Error response body (all error statuses)

```json
{
  "error": "note_not_found",
  "message": "No note exists with this ID."
}
```

Known `error` codes for v1:

| Code | HTTP | Maps to |
|------|------|---------|
| `unauthorized` | 401 | `NoteRepositoryError.notAuthenticated` |
| `note_not_found` | 404 | `NoteRepositoryError.noteNotFound` |
| `validation_error` | 400 | `NoteRepositoryError.validationError` |
| (other / network) | any | `NoteRepositoryError.networkError` or `.serverError` |

### 10. NoteRepositoryError

```swift
public enum NoteRepositoryError: Error, Equatable, Sendable {
    case notAuthenticated
    case noteNotFound
    case validationError(String)
    case networkError
    case serverError(statusCode: Int)
}
```

### 11. Internal HTTP client (not a public protocol)

`NoteAPIClient` is `internal` to `NoteRepository` target. Injectable `URLSession` for tests via internal init.

**Rationale:** Matches `VaultRepository` / `AuthRepository` pattern. Tests use `URLProtocol` stubs.

### 12. Package dependency on VaultRepositoryProtocol

`NoteRepository` target depends on `VaultRepositoryProtocol` for `AccessTokenProviding` only. `NoteRepositoryProtocol` has no dependency on other project packages.

**Rationale:** Reuses existing `AuthRepositoryAccessTokenProvider` at composition root. Avoids duplicating token protocol.

### 13. Products and import guidance

| Consumer | Import |
|----------|--------|
| NotesFlow / note service (future) | `NoteRepositoryProtocol` |
| App composition root | `NoteRepository` + `NoteRepositoryProtocol` |
| Tests / mocks | `NoteRepositoryProtocol` |

`NoteRepository` target `@_exported import NoteRepositoryProtocol` at module entry.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| No backend yet — integration untested against real server | Define API contract in design; use `URLProtocol` stub tests; backend follows same contract |
| Last-write-wins on upload — multi-device race | Documented v1 limitation; ETag/conflict detection deferred |
| Server must parse binary `.note` header to index metadata | Document SSNT v1 header field layout in backend contract; format is stable in `add-secure-crypto` |
| Plaintext titles visible to server | Accepted threat model; metadata already plaintext in `.note` header by design |
| Large note blobs uploaded whole | v1 whole-blob upload; streaming/chunking deferred |
| Token expiry during note operation | Caller refreshes session via `AuthRepository` before note calls; auto-refresh deferred |

## Migration Plan

Greenfield addition — no migration.

1. Add `Packages/NoteRepository` with TDD
2. Link products in Xcode project (no runtime wiring until note data layer exists)
3. Build backend implementing REST contract from this design
4. Future: note service wires `readNote` / `writeNote` with `SecureCrypto` and `VaultSession`

Rollback: remove package reference from Xcode; delete `Packages/NoteRepository/`.

## Open Questions

None — exploration decisions captured above.
