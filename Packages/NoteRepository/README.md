# NoteRepository

Swift package providing server-backed note blob storage and indexed note listing for superSecureNotes.

## Module layout

```
superSecureNotes (app)
    ├── NoteRepositoryProtocol   ← NotesFlow, note services, feature modules
    └── NoteRepository           ← composition root / network implementation

NoteRepository
    ├── NoteRepositoryProtocol
    └── VaultRepositoryProtocol  (AccessTokenProviding only)

NoteRepositoryProtocol
    └── Foundation only
```

### Source folders

```
Sources/NoteRepositoryProtocol/
├── NoteRepository.swift         NoteRepository protocol
├── NoteRepositoryError.swift
└── Models/NoteSummary.swift

Sources/NoteRepository/
├── NoteRepository.swift         re-export entry point
├── NetworkNoteRepository.swift  actor implementation
└── Internal/                    NoteAPIClient, JSON DTOs (not public)

Tests/ mirror the same folders per target.
```

## Import guidance

| Consumer | Import | Why |
|----------|--------|-----|
| NotesFlow / note service (future) | `NoteRepositoryProtocol` | Protocol and models only |
| App composition root | `NoteRepository` | Wire `NetworkNoteRepository` at startup |
| Tests / mocks | `NoteRepositoryProtocol` | Mock `NoteRepository` without networking |

`NoteRepository` re-exports `NoteRepositoryProtocol` via `@_exported import`.

## Responsibilities

**NoteRepository owns:**

- List notes with server-indexed metadata (`noteId`, `title`, `updatedAt`)
- Upload/download/delete encrypted `.note` blobs for the authenticated user
- Bearer token auth via injected `AccessTokenProviding` (from `VaultRepositoryProtocol`)
- Mapping HTTP errors to `NoteRepositoryError`

**NoteRepository does not:**

- Parse or validate `NoteMetadata` / encrypt note content (callers use `SecureCrypto`)
- `VaultSession` integration or local file storage
- Sharing endpoints or recipient management
- Conflict resolution / ETags (last-write-wins in v1)

## v1 REST API contract

Base URL is configured at `NetworkNoteRepository` init (e.g. `https://api.example.com/v1`).

All endpoints require `Authorization: Bearer <accessToken>`.

| Method | Path | Success | Body |
|--------|------|---------|------|
| GET | `/notes` | 200 | `[{ "noteId": "<uuid>", "title": "...", "updatedAt": 123 }]` |
| GET | `/notes/{noteId}` | 200 | Raw binary `.note` |
| PUT | `/notes/{noteId}` | 204 | Raw binary `.note` (`application/octet-stream`) |
| DELETE | `/notes/{noteId}` | 204 | — |

On `PUT`, the server indexes plaintext metadata from the SSNT v1 header for list responses.

Error responses:

```json
{ "error": "note_not_found", "message": "..." }
```

Known error codes: `unauthorized`, `note_not_found`, `validation_error`.

## Products

- **NoteRepositoryProtocol** — `NoteRepository` protocol, `NoteSummary`, `NoteRepositoryError`
- **NoteRepository** — `actor NetworkNoteRepository` default implementation

## Testing

```bash
cd Packages/NoteRepository && swift test
```

Network tests use `URLProtocol` stubs — no live backend required.
