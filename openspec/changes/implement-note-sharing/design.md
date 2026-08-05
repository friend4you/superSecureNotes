## Context

`ShareNote` provides `ShareNoteRoute.share(noteID:)` and a placeholder screen presented as a sheet from `NotesFlow`. `VaultRepository` fetches public keys by `userID` only. `SecureCrypto` wraps note FEKs with the UDK (symmetric) but has no recipient wrap. The backend exposes:

| Endpoint | Role |
|----------|------|
| `GET /v1/users/public-key?email=` | Recipient lookup for share |
| `POST /v1/notes/{note_id}/share` | `{ recipientEmail, wrappedFek }` base64 grant |
| `GET /v1/notes/shared` | Incoming share summaries |
| `GET /v1/notes/shared/{note_id}` | `{ noteId, wrappedFek, blob }` for recipient read |

Recipients unwrap the grant FEK with their vault identity private key (not UDK). Shared notes are read-only — no PUT on shared endpoints.

## Goals / Non-Goals

**Goals:**

- Simple share screen: email field + Share button with loading/error/success feedback
- End-to-end share: unwrap owner FEK locally → wrap for recipient public key → POST grant
- Segmented note list: `My Notes` | `Shared` using `GET /v1/notes/shared`
- Read-only shared detail: owner email, title, body, attachment preview; no edit toolbar
- `fetchPublicKey(email:)` on `VaultRepository`
- Recipient FEK wrap/unwrap in `SecureCrypto`
- Share blocked when note `syncState != .synced`
- Strict TDD throughout

**Non-Goals:**

- Revoke share UI (`DELETE .../share/{email}`)
- List of outgoing recipients on owned note detail (no list API)
- Editing or saving shared notes
- Local cache/index of shared notes (network fetch per session for v1)
- Stub-backend share simulation
- macOS-specific polish beyond existing package platform support

## Decisions

### 1. Segmented control on `NoteListView`

```
┌─────────────────────────────────────┐
│  [ My Notes | Shared ]              │
│  ─────────────────────────────────  │
│  (list for selected segment)        │
└─────────────────────────────────────┘
```

**Rationale:** User chose segmented control — minimal navigation change, no new root route or tab bar.

**Alternatives considered:**
- Toolbar push to separate list — extra navigation depth; rejected
- Combined single list with badges — harder to scan; rejected

### 2. Separate route: `NotesRoute.sharedDetail(noteID:)`

Owned detail stays `NotesRoute.detail(noteID:)` (editable). Shared detail uses a new case so ViewModels and views do not branch on runtime flags.

**Rationale:** Clear separation of read-only vs editable; avoids accidental save on shared notes.

### 3. Recipient FEK wrap format

```
share_wrapped_fek wire blob:
  magic "SSNF" (4 bytes)
  version 1 (1 byte)
  algorithm_id 1 = Curve25519 (1 byte)
  ephemeral_public_key (32 bytes)
  wrapped_fek_length (UInt16 BE)
  wrapped_fek_bytes (ChaChaPoly wrap output from existing wrapKey)
```

Wrap algorithm:
1. Generate ephemeral `Curve25519.KeyAgreement.PrivateKey`
2. `sharedSecret = ephemeral.private.sharedSecretFromKeyAgreement(with: recipientPublicKey)`
3. `wrappingKey = HKDF-SHA256(sharedSecret, info: "superSecureNotes.share.fek.v1", outputLength: 32)`
4. `wrapped = wrapKey(fek, with: wrappingKey)` (existing symmetric wrap)
5. Assemble wire blob; base64-encode for API `wrappedFek` field

Unwrap (recipient):
1. Parse wire blob; extract ephemeral public key + wrapped bytes
2. `sharedSecret = identityPrivate.sharedSecretFromKeyAgreement(with: ephemeralPublic)`
3. Same HKDF info → `wrappingKey`
4. `fek = unwrapKey(wrapped, with: wrappingKey)`
5. Decrypt note blob with existing `decryptPayload`

**Rationale:** Reuses existing ChaChaPoly wrap primitive; ephemeral X25519 provides forward secrecy per share grant; versioned wire blob allows future algorithm IDs.

**Alternatives considered:**
- Raw `CryptoKit.SealedBox` — different format from existing FEK wrap; rejected for consistency
- Symmetric wrap with recipient public key directly — not possible; rejected

### 4. Share orchestration in `DefaultShareNoteViewModel`

Dependencies:
- `noteRepository` — `readNote` for FEK, `shareNote` for POST
- `vaultRepository` — `fetchPublicKey(email:)`
- `vaultSession` — `udk()` to unwrap owner's FEK before re-wrapping
- `navigator` — dismiss sheet on success

Flow:
```
share(email)
  → validate email non-empty
  → readNote(noteID) → unwrapFEK(udk)
  → fetchPublicKey(email) → wrapFEKForRecipient(fek, publicKey)
  → shareNote(noteID, email, base64(wireBlob))
  → dismiss on success
```

**Rationale:** Matches `NoteDetailViewModel` pattern (orchestration in VM, repos for I/O).

### 5. Shared note read path

`readSharedNote(noteID:)` returns a `SharedNote` model:
- `metadata` parsed from blob header (title, etc.)
- `ownerEmail` from list summary (passed through navigation or re-fetched)
- `encryptedPayload` + `recipientWrappedFEK` from download response

Detail VM decrypts with `vaultSession.identityPrivateKey()` + `unwrapSharedFEK`.

**Rationale:** Shared download API returns a different shape than owned `readNote`; dedicated model avoids overloading `StoredNote`.

### 6. Share prerequisite: note must be synced

Before POST share, VM checks `storedNote.syncState == .synced`. Otherwise show localized error ("Sync this note before sharing").

**Rationale:** Recipient download serves the owner's server blob; unsynced notes have no blob for the recipient.

### 7. `LocalNoteRepository` / stub sharing

`listSharedNotes()` returns `[]`, `readSharedNote` throws `notSupported`, `shareNote` throws `notSupported`. Network path only for v1.

**Rationale:** Matches existing stub-backend scope; share requires real API.

### 8. `VaultRepository.fetchPublicKey(email:)`

`GET /v1/users/public-key?email={email}` — same `PublicKeyResponse` JSON as userID variant. Reject empty email locally with `validationError`.

Keep existing `fetchPublicKey(userID:)` unchanged.

## Risks / Trade-offs

- **[Crypto wire format mismatch with backend expectations]** → Backend stores opaque base64; document format in spec; integration test against localhost API
- **[Share without synced note]** → Explicit guard + user message
- **[Shared notes always require network]** → Acceptable v1; no offline shared cache
- **[Email typo shares to wrong person]** → Standard email validation only; no confirmation step in v1
- **[VM crypto orchestration]** → Acceptable v1; extract service if share logic grows

## Migration Plan

Additive change — no data migration.

1. Ship crypto + repository APIs
2. Ship ShareNote UI
3. Ship NotesFlow segmented list + shared detail
4. Wire app composition

Rollback: revert package changes; share sheet returns to placeholder behavior.

## Open Questions

- None — segmented control confirmed; read-only shared detail confirmed; email public-key endpoint confirmed on backend.
