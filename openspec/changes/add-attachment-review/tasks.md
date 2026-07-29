## 1. NoteAttachmentItem and localization

- [ ] 1.1 Write failing tests: `NoteAttachmentItem` has id, filename, mime; attachment localization keys exist in catalog (`NotesFlowTests/NoteAttachmentItemTests.swift`, `NotesFlowTests/Localization/LocalizationTests.swift`)
- [ ] 1.2 Add `NoteAttachmentItem` model and localization keys for attachment section, remove, and preview labels; make tests pass

## 2. QuickLook preview (iOS)

- [ ] 2.1 Write failing tests: temp file writer creates and deletes preview file; QuickLook representable compiles on iOS (`NotesFlowTests/AttachmentPreviewTests.swift`)
- [ ] 2.2 Implement `AttachmentPreviewStore` (write bytes to temp path, delete on cleanup) and `QuickLookPreview` UIViewControllerRepresentable gated with `#if os(iOS)`; make tests pass

## 3. CreateNoteViewModel attachment API

- [ ] 3.1 Write failing tests: `attachmentItems` published on add/remove; `attachmentData(for:)` returns bytes; `removeAttachment` updates items (`NotesFlowTests/DefaultCreateNoteViewModelTests.swift`)
- [ ] 3.2 Replace `attachmentFilenames` with `attachmentItems` and add `attachmentData(for:)` on create VM and protocol; make tests pass

## 4. NoteDetailViewModel attachment API

- [ ] 4.1 Write failing tests: load populates `attachmentItems`; `addAttachment`/`removeAttachment` update items; `hasChanges` true on attachment edit; `canSave` reflects attachment dirty state; save persists attachment changes; `attachmentData(for:)` returns bytes (`NotesFlowTests/DefaultNoteDetailViewModelTests.swift`)
- [ ] 4.2 Add `addAttachment`, `removeAttachment`, `attachmentItems`, `attachmentData(for:)`, and attachment-aware `hasChanges` to detail VM and protocol; make tests pass

## 5. Shared NoteAttachmentsSection

- [ ] 5.1 Write failing tests: section hidden when empty; rows render filename; trash calls remove callback; tap calls preview callback (`NotesFlowTests/NoteAttachmentsSectionTests.swift` — source/VM seam tests where layout inspection is impractical)
- [ ] 5.2 Implement `NoteAttachmentsSection` with trash button, tap handler, and iOS preview sheet integration; make tests pass

## 6. CreateNoteView integration

- [ ] 6.1 Write failing tests: create view uses shared section; trash invokes `removeAttachment`; photo/file pickers still add attachments (`NotesFlowTests/CreateNoteViewTests.swift`)
- [ ] 6.2 Refactor `CreateNoteView` to use `NoteAttachmentsSection`; remove duplicate filename list; make tests pass

## 7. NoteDetailView integration

- [ ] 7.1 Write failing tests: detail view uses shared section; includes photo/file pickers; trash invokes `removeAttachment` (`NotesFlowTests/NoteDetailViewTests.swift` — VM seam or source tests)
- [ ] 7.2 Refactor `NoteDetailView` to use `NoteAttachmentsSection` and add `PhotosPicker`/`fileImporter`; make tests pass

## 8. Verification

- [ ] 8.1 Run full `NotesFlow` test suite and fix any regressions from `attachmentFilenames` removal
