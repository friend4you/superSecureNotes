## Context

`NoteRepository` exposes `listNotes()`, `readNote`, `writeNote`, and `deleteNote` with raw `.note` `Data` blobs. `SecureCrypto` provides `parseNoteFile`, `assembleNoteFile`, FEK wrap/unwrap, and payload encrypt/decrypt. `VaultSession` provides `udk()` for FEK operations. `ShareNoteRoute.share(noteID:)` is registered but not reachable from notes UI. `FileVaultRepository` and `InMemoryAuthRepository` exist for stub mode; note persistence stub does not.

`NotesFlow` currently shows placeholder text, has `DefaultNoteListViewModel` with DEBUG logout and experimental share push, and depends on `AuthRepositoryProtocol` and `VaultSessionProtocol` only.

## Goals / Non-Goals

**Goals:**

- Three routed screens: list, detail (push), create (push)
- List shows `NoteSummary.title`; pull-to-refresh; inline loading/error text
- Detail: always edit; Save disabled when unchanged or title empty; Share sheet; Delete with confirmation alert; pop after delete
- Create: Save requires non-empty title; attachments via `PhotosPicker` + `fileImporter` (images, PDF, plain text); pop on save
- List context menu: Share (sheet) and Delete (confirmation)
- Settings toolbar button: no action; `// TODO:` in code (no route)
- ViewModels perform crypto orchestration v1 (read blob → parse → unwrap FEK → decrypt payload; save reverses with new FEK on create)
- `FileNoteRepository` in app `Stub/` for `-UseStubBackend`
- Localization for all user-visible strings in `NotesFlow`
- `DefaultShareNoteViewModel.dismiss()` calls `navigator.dismissPresentation()`
- Strict TDD aligned with `development-practices`

**Non-Goals:**

- Separate `NotesFlowProtocol` target or use-case package
- `SettingsFlow` or settings screen
- Share recipient lookup, encryption, or payload generation
- Rich text editor, markdown, or attachment previews beyond filename list
- Attachment size/mime enforcement beyond picker defaults
- Swipe-to-delete on list rows
- `NotesRoute.settings`
- Release-build stub note repository
- ETag/conflict handling on write

## Decisions

### 1. Crypto orchestration in ViewModels (v1)

`DefaultNoteDetailViewModel` and `DefaultCreateNoteViewModel` import `SecureCrypto` and call:

```
read:  readNote → parseNoteFile → unwrapFEK(udk) → decryptPayload → NotePayload
write: encryptPayload → wrapFEK → assembleNoteFile → writeNote
create: generateSymmetricKey() for new FEK; new UUID for noteID
```

**Rationale:** User chose ViewModel layer for v1; avoids premature abstraction.

**Alternatives considered:**
- Dedicated `NoteVaultService` package — rejected for v1 scope
- Repository returns decrypted models — rejected; repo stays raw `Data`

### 2. Route cases and presentation

```swift
public enum NotesRoute: Route {
    case list
    case detail(noteID: UUID)
    case create
}
```

- List → detail: `push(.detail(noteID:))`
- List → create: `push(.create)`
- Share: `present(ShareNoteRoute.share(noteID:), style: .sheet)` (not a `NotesRoute`)

**Rationale:** Matches exploration decisions; share stays cross-package.

### 3. Save button gating

| Screen | Save enabled when |
|--------|-------------------|
| Detail | `hasChanges && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false` |
| Create | same rule |

**Rationale:** Title required in `NoteMetadata`; body and attachments optional.

### 4. Delete UX

- List: context menu → Delete → confirmation alert → `deleteNote` → refresh list
- Detail: toolbar/menu Delete → confirmation alert → `deleteNote` → `pop()`
- Share: no delete

**Rationale:** Destructive actions need confirmation; detail pops after success.

### 5. Attachment pickers (create only)

- `PhotosPicker` for images (JPEG, PNG, HEIC)
- `fileImporter` with `UTType` set: `.image`, `.pdf`, `.plainText`, `.data` (common documents)

Display attachment filenames in a list below editors; store as `NotePayload.Attachment` with generated UUID string id.

**Rationale:** User requested both pickers, common types only.

### 6. FileNoteRepository stub

```
Application Support/stub-notes/{noteId}.note
```

- `listNotes()`: scan directory, parse plaintext header via `NoteMetadata.fromNoteFile` for each file
- `readNote` / `writeNote` / `deleteNote`: file per note ID
- Lives in `superSecureNotes/Stub/FileNoteRepository.swift` under `#if DEBUG`

`AppDependencies` selects `FileNoteRepository` when `StubBackendConfiguration.isEnabled`, else `NetworkNoteRepository`.

**Rationale:** Mirrors `FileVaultRepository` pattern; enables full stub journey without API.

### 7. Localization

- `defaultLocalization: "en"` on `NotesFlow` package
- `Resources/Localizable.xcstrings`
- `NotesFlowUILocalization.localized(_:)` helper
- `LocalizationTests` asserting catalog bundled (mirror `AuthFlowUI`)

### 8. Settings button stub

Toolbar gear button with empty action body containing `// TODO: Implement settings navigation`.

No navigation, no route case.

### 9. Share dismiss fix

`DefaultShareNoteViewModel.dismiss()` → `navigator.dismissPresentation()` instead of `pop()`.

Update existing dismiss test in `ShareNoteTests`.

### 10. Inline loading and error UI

- List/detail/create expose `isLoading` and optional `errorMessage` on ViewModels
- Views show `ProgressView` or inline `Text` for errors below main content (not alerts for load/save failures)

### 11. List ordering

Sort `NoteSummary` by `updatedAt` descending client-side after `listNotes()`.

## Risks / Trade-offs

- **[Crypto logic in ViewModels]** → Acceptable v1; extract service when share/edit complexity grows
- **[FileNoteRepository list scans all files]** → Fine for stub; network `listNotes` uses server index
- **[Large attachments in memory]** → v1 no size limits; document as follow-up
- **[ShareNote dismiss change]** → May affect any push-based share entry; notes use sheet only
- **[Title-only notes]** → Empty body stored as empty `Data` in payload

## Migration Plan

Incremental within one change:

1. Stub repo + app wiring
2. Routes + localization scaffold
3. List screen (read-only data)
4. Detail screen
5. Create screen
6. Share wiring + dismiss fix
7. Delete flows + polish

Rollback: revert package and app changes; delete stub notes directory.

## Open Questions

- None — exploration decisions captured above
