## 1. SecureCrypto — NotePayload v2 and attachment crypto

- [x] 1.1 Write failing tests: v2 `NotePayload` encodes `schemaVersion`, index entries without `data`, encrypt/decrypt roundtrip (`NotePayloadV2Tests`)
- [x] 1.2 Implement v2 model + encoding; make tests pass
- [x] 1.3 Write failing tests: v1 inline payload still decrypts; migration helper returns v2 index + bytes map with new UUID ids (`NotePayloadMigrationTests`)
- [x] 1.4 Implement v1 detection and `migratePayloadV1ToV2`; make tests pass
- [x] 1.5 Write failing tests: attachment file encrypt/decrypt with note FEK (`AttachmentFileCryptoTests`)
- [x] 1.6 Implement attachment encrypt/decrypt helpers; make tests pass

## 2. NotesIndexStore — body etag and attachment rows

- [x] 2.1 Write failing tests: `attachments` table CRUD by `(note_id, attachment_id)`; note row stores `body_etag` and `etag` (`NotesIndexStoreAttachmentTests`)
- [x] 2.2 Add schema migration + queries; make tests pass
- [x] 2.3 Write failing tests: `attachment_upload_sessions` keyed by `(note_id, attachment_id)` (`NotesIndexStoreAttachmentUploadSessionTests`)
- [x] 2.4 Add attachment upload session table (adapt from note upload sessions); make tests pass

## 3. LocalNoteRepository — split file layout

- [x] 3.1 Write failing tests: write/read stores `body` SSNT file + `attachments/{id}` ciphertext files (`LocalNoteRepositorySplitStorageTests`)
- [x] 3.2 Implement split read/write paths; make tests pass
- [x] 3.3 Write failing tests: legacy `payload` file migrates to split layout on read (`LocalNoteRepositoryMigrationTests`)
- [x] 3.4 Implement lazy migration from legacy `payload`; make tests pass
- [x] 3.5 Write failing tests: `deleteNote` removes body, attachments dir, and attachment index rows (`LocalNoteRepositoryDeleteTests` update)
- [x] 3.6 Update delete to cascade attachments; make tests pass

## 4. NoteAPIClient — split body/attachment endpoints

- [x] 4.1 Write failing tests: `readBody`/`writeBody` use `/v1/notes/{id}/body`; list attachments manifest (`NoteAPIClientBodyTests`)
- [x] 4.2 Implement body + manifest client methods; make tests pass
- [x] 4.3 Write failing tests: attachment GET/PUT/DELETE use `/attachments/{attachmentId}` with `application/octet-stream` (`NoteAPIClientAttachmentTests`)
- [x] 4.4 Implement attachment CRUD client methods; make tests pass
- [x] 4.5 Write failing tests: attachment chunked upload under `/attachments/{attachmentId}/uploads` (`NoteAPIClientAttachmentChunkedUploadTests`)
- [x] 4.6 Implement attachment chunked upload client; make tests pass
- [x] 4.7 Write failing tests: shared body/attachment endpoints (`NoteSharingAPIClientSplitTests`)
- [x] 4.8 Implement shared split endpoints; make tests pass

## 5. NetworkNoteRepository — split mapping

- [x] 5.1 Write failing tests: `readNote` fetches body only; attachments fetched separately when requested (`NetworkNoteRepositorySplitReadTests`)
- [x] 5.2 Implement split read mapping; remove monolithic note GET; make tests pass
- [x] 5.3 Write failing tests: `uploadNote` PUTs body then each attachment; uses chunked path when attachment > threshold (`NetworkNoteRepositorySplitUploadTests`)
- [x] 5.4 Implement multi-part upload; remove monolithic note PUT; make tests pass

## 6. LocalFirstNoteSyncService — multi-part upload

- [x] 6.1 Write failing tests: note stays `pendingSync` until body + all attachments succeed; emits outcome when complete (`LocalFirstNoteSyncServiceSplitUploadTests`)
- [x] 6.2 Implement split upload orchestration in `flushPending`; make tests pass
- [x] 6.3 Write failing tests: etag conflict retries full reupload from local; attachment session resume keyed by `(note_id, attachment_id)` (`LocalFirstNoteSyncServiceAttachmentUploadSessionTests`)
- [x] 6.4 Integrate attachment upload sessions + local-wins retry; make tests pass
- [x] 6.5 Write failing tests: v1 note migration triggers `pendingSync` and split upload on flush (`LocalFirstNoteSyncServiceMigrationTests`)
- [x] 6.6 Wire migration hook into sync path; make tests pass

## 7. LocalFirstNoteSyncService — attachment hydration

- [x] 7.1 Write failing tests: `hydrateAttachments(noteID:)` downloads missing files; max 3 concurrent; continues after caller cancelled (`AttachmentHydrationTests`)
- [x] 7.2 Implement hydration actor logic in sync service; make tests pass
- [x] 7.3 Write failing tests: progress stream emits per-attachment `bytesReceived/totalBytes`; retry single id (`AttachmentHydrationProgressTests`)
- [x] 7.4 Expose progress + per-id retry API; make tests pass
- [x] 7.5 Write failing tests: shared note hydration uses `/v1/notes/shared/...` paths (`SharedAttachmentHydrationTests`)
- [x] 7.6 Implement shared hydration paths; make tests pass

## 8. NotesFlow — save gating and hydration UI

- [x] 8.1 Write failing tests: `canSave` false when `syncState == pendingSync`; true when synced and dirty (`DefaultNoteDetailViewModelSaveGateTests`)
- [x] 8.2 Update detail/create view models save gating; make tests pass
- [x] 8.3 Write failing tests: detail `load()` shows body before attachments; subscribes to hydration progress (`DefaultNoteDetailViewModelHydrationTests`)
- [x] 8.4 Wire hydration subscription + fast body open in detail VM; make tests pass
- [x] 8.5 Write failing tests: `NoteAttachmentsSection` shows per-row progress and retry (`NoteAttachmentsSectionProgressTests`)
- [x] 8.6 Update `NoteAttachmentsSection` + detail/shared views for progress UI; make tests pass
- [x] 8.7 Write failing tests: shared detail same hydration behavior (`DefaultSharedNoteDetailViewModelHydrationTests`)
- [x] 8.8 Update shared detail VM; make tests pass

## 9. App composition and cleanup

- [x] 9.1 Write failing tests: `NotesFlowDependencies` passes hydration/progress source from sync service (`NotesFlowDependenciesSplitTests`)
- [x] 9.2 Wire dependencies in `AppComposition`; make tests pass
- [x] 9.3 Write failing tests: dead monolithic note upload paths are not called (`NetworkNoteRepositoryLegacyPathRemovalTests`)
- [x] 9.4 Remove or no-op legacy `/v1/notes/{id}` content upload/read; make tests pass

## 10. Manual verification

- [ ] 10.1 Create note with attachments → detail opens with text immediately on cold sync → per-attachment progress → preview works
- [ ] 10.2 Leave detail during download → re-open → attachments complete in background
- [ ] 10.3 Save disabled while pending; enabled after synced; edit + save cycles correctly
- [ ] 10.4 Shared note cold open shows same progress behavior
- [ ] 10.5 Legacy local note with inline attachments migrates and reuploads on next sync
