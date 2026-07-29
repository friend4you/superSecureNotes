## Why

Notes can include encrypted attachments, but the UI only shows filenames — users cannot preview, add, or remove attachments when viewing or editing a note. `expand-notes-flow` intentionally deferred attachment previews and detail-side attachment management; this change completes the attachment journey on create and detail screens.

## What Changes

- Add shared `NoteAttachmentsSection` UI used by `CreateNoteView` and `NoteDetailView` — attachment rows with filename, trash button, tap-to-preview
- Add iOS QuickLook-based `AttachmentPreviewView` — write decrypted bytes to a temp file, present `QLPreviewController`, delete temp file on dismiss
- Expose `NoteAttachmentItem` (id, filename, mime) from create and detail ViewModels instead of bare filename strings
- Wire trash button to `removeAttachment(id:)` on both screens (create VM already has the API; detail VM gains it)
- Add `addAttachment` / `removeAttachment` to `DefaultNoteDetailViewModel`; include attachment changes in `hasChanges` / `canSave` (Save required before persistence)
- Add `PhotosPicker` and `fileImporter` to `NoteDetailView` (same allowed types as create: images, PDF, plain text)
- Add `attachmentData(for:)` (or equivalent) on ViewModels for preview data access
- Fix attachment list identity to use attachment `id` instead of `filename`
- Add localized strings for preview, remove, and attachment actions
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

<!-- No new top-level capability packages -->

### Modified Capabilities

- `notes-flow`: Attachment preview via QuickLook, shared attachment section UI, add/remove attachments on create and detail, detail `hasChanges` tracks attachment edits

## Impact

- `Packages/NotesFlow/` — new shared views (`NoteAttachmentsSection`, `QuickLookPreview`), ViewModel protocol/API updates, localization strings, tests
- No changes to `SecureCrypto`, `NoteRepository`, or `.note` format
- iOS only for QuickLook preview in v1; macOS preview deferred
- Out of scope: attachment thumbnails in list rows, note-list attachment badge, share individual attachment, widen file importer to all UTTypes, attachment size limits, macOS QuickLook parity
