## Context

`NotesFlow` create and detail screens already encrypt and decrypt `NotePayload.Attachment` values (id, filename, mime, inline data) via `SecureCrypto`. The UI only renders attachment filenames as static `Text` rows. `DefaultCreateNoteViewModel` exposes `addAttachment` and `removeAttachment`, but neither view wires remove UI or preview. `DefaultNoteDetailViewModel` keeps attachments private and does not expose add/remove; `hasChanges` ignores attachment edits.

`expand-notes-flow` explicitly deferred attachment previews and detail-side attachment management.

## Goals / Non-Goals

**Goals:**

- Shared attachment section on create and detail: rows with filename, trash button, tap-to-preview
- iOS QuickLook preview for any attachment type the system can render
- Add attachments on detail (same pickers as create: images, PDF, plain text)
- Remove attachments on create and detail via trash button
- Detail attachment changes require Save (same as title/body)
- Expose `NoteAttachmentItem` (id, filename, mime) from ViewModels; preview fetches bytes by id
- Localized strings for attachment actions
- Strict TDD aligned with `development-practices`

**Non-Goals:**

- macOS QuickLook preview (iOS first)
- Inline thumbnails in attachment rows
- Attachment count badge on note list
- Share/export individual attachment
- Widen `fileImporter` to all UTTypes (keep image, PDF, plain text)
- Attachment size limits or streaming
- Changes to `SecureCrypto`, `NoteRepository`, or `.note` format

## Decisions

### 1. QuickLook for preview (iOS)

On row tap, write attachment bytes to a unique file under `FileManager.default.temporaryDirectory`, present `QLPreviewController` via `UIViewControllerRepresentable`, delete the temp file when the preview sheet dismisses.

**Rationale:** One code path covers images, PDF, text, and many other system-supported types with minimal code.

**Alternatives considered:**

- Custom per-MIME viewers (Image, PDFKit, Text) — more code, narrower coverage
- Share sheet as fallback — leaves the app; not true in-app review

### 2. Shared `NoteAttachmentsSection`

Extract attachment list, trash buttons, add pickers, and preview presentation into a reusable SwiftUI view parameterized by a small protocol or closures (`attachmentItems`, `onRemove`, `onAdd`, `dataForPreview`).

**Rationale:** Create and detail share identical attachment UX; avoids duplication.

### 3. `NoteAttachmentItem` display model

ViewModels expose `[NoteAttachmentItem]` with `id`, `filename`, `mime` (no raw `Data` in the public model). Preview requests bytes via `attachmentData(for id: String) -> Data?`.

**Rationale:** Keeps observation lightweight; data already resident in VM memory after load.

### 4. Detail attachment mutations follow Save semantics

`DefaultNoteDetailViewModel` snapshots `loadedAttachments` on load. `hasChanges` is true when title, body, or attachments differ from loaded state. `save()` re-encrypts the current attachment array.

**Rationale:** Consistent with existing detail edit flow; no auto-save surprises.

### 5. Trash button (not swipe-to-delete)

Each attachment row shows a trailing trash `Button` calling `removeAttachment(id:)`.

**Rationale:** User preference; explicit and discoverable in a `Form` layout.

### 6. List identity by attachment id

`ForEach` uses `attachment.id`, not `filename`, to support duplicate filenames.

**Rationale:** Fixes latent bug in current filename-keyed lists.

### 7. Temp file security

Write preview files to a per-preview subdirectory under the system temp directory. Delete file and directory on dismiss. Optional: set file protection where applicable.

**Rationale:** Minimize decrypted data lifetime on disk.

## Risks / Trade-offs

- **[Decrypted temp files on disk]** → Delete immediately on preview dismiss; use unique subdirectory per session
- **[Large attachments in memory]** → Unchanged from today; full payload already loaded on note open
- **[QuickLook unsupported types]** → System may show generic preview or empty state; acceptable for v1
- **[macOS package target]** → QuickLook wrapper gated with `#if os(iOS)`; macOS shows no preview action or disabled state until follow-up

## Migration Plan

No data migration. Existing `.note` blobs unchanged. Ship as UI-only `NotesFlow` update.

## Open Questions

None — scope locked in explore session.
