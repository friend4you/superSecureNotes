## 1. SecureCrypto — NotePayload v2 and attachment crypto

- [ ] 1.1 Write failing tests: v2 `NotePayload` encodes `schemaVersion`, index entries without `data`, encrypt/decrypt roundtrip (`NotePayloadV2Tests`)
- [ ] 1.2 Implement v2 model + encoding; make tests pass
- [ ] 1.3 Write failing tests: v1 inline payload still decrypts; migration helper returns v2 index + bytes map with new UUID ids (`NotePayloadMigrationTests`)
- [ ] 1.4 Implement v1 detection and `migratePayloadV1ToV2`; make tests pass
- [ ] 1.5 Write failing tests: attachment file encrypt/decrypt with note FEK (`AttachmentFileCryptoTests`)
- [ ] 1.6 Implement attachment encrypt/decrypt helpers; make tests pass

## 2. NotesIndexStore — body etag and attachment rows

- [ ] 2.1 Write failing tests: `attachments` table CRUD by `(note_id, attachment_id)`; note row stores `body_etag` and `etag` (`NotesIndexStoreAttachmentTests`)
- [ ] 2.2 Add schema migration + queries; make tests pass
- [ ] 2.3 Write failing tests: `attachment_upload_sessions` keyed by `(note_id, attachment_id)` (`NotesIndexStoreAttachmentUploadSessionTests`)
- [ ] 2.4 Add attachment upload session table (adapt from note upload sessions); make tests pass

## 3. LocalNoteRepository — split file layout

- [ ] 3.1 Write failing tests: write/read stores `body` SSNT file + `attachments/{id}` ciphertext files (`LocalNoteRepositorySplitStorageTests`)
- [ ] 3.2 Implement split read/write paths; make tests pass
- [ ] 3.3 Write failing tests: legacy `payload` file migrates to split layout on read (`LocalNoteRepositoryMigrationTests`)
- [ ] 3.4 Implement lazy migration from legacy `payload`; make tests pass
- [ ] 3.5 Write failing tests: `deleteNote` removes body, attachments dir, and attachment index rows (`LocalNoteRepositoryDeleteTests` update)
- [ ] 3.6 Update delete to cascade attachments; make tests pass

## 4. NoteAPIClient — split body/attachment endpoints

- [ ] 4.1 Write failing tests: `readBody`/`writeBody` use `/v1/notes/{id}/body`; list attachments manifest (`NoteAPIClientBodyTests`)
- [ ] 4.2 Implement body + manifest client methods; make tests pass
- [ ] 4.3 Write failing tests: attachment GET/PUT/DELETE use `/attachments/{attachmentId}` with `application/octet-stream` (`NoteAPIClientAttachmentTests`)
- [ ] 4.4 Implement attachment CRUD client methods; make tests pass
- [ ] 4.5 Write failing tests: attachment chunked upload under `/attachments/{attachmentId}/uploads` (`NoteAPIClientAttachmentChunkedUploadTests`)
- [ ] 4.6 Implement attachment chunked upload client; make tests pass
- [ ] 4.7 Write failing tests: shared body/attachment endpoints (`NoteSharingAPIClientSplitTests`)
- [ ] 4.8 Implement shared split endpoints; make tests pass

## 5. NetworkNoteRepository — split mapping

- [ ] 5.1 Write failing tests: `readNote` fetches body only; attachments fetched separately when requested (`NetworkNoteRepositorySplitReadTests`)
- [ ] 5.2 Implement split read mapping; remove monolithic note GET; make tests pass
- [ ] 5.3 Write failing tests: `uploadNote` PUTs body then each attachment; uses chunked path when attachment > threshold (`NetworkNoteRepositorySplitUploadTests`)
- [ ] 5.4 Implement multi-part upload; remove monolithic note PUT; make tests pass

## 6. LocalFirstNoteSyncService — multi-part upload

- [ ] 6.1 Write failing tests: note stays `pendingSync` until body + all attachments succeed; emits outcome when complete (`LocalFirstNoteSyncServiceSplitUploadTests`)
- [ ] 6.2 Implement split upload orchestration in `flushPending`; make tests pass
- [ ] 6.3 Write failing tests: etag conflict retries full reupload from local; attachment session resume keyed by `(note_id, attachment_id)` (`LocalFirstNoteSyncServiceAttachmentUploadSessionTests`)
- [ ] 6.4 Integrate attachment upload sessions + local-wins retry; make tests pass
- [ ] 6.5 Write failing tests: v1 note migration triggers `pendingSync` and split upload on flush (`LocalFirstNoteSyncServiceMigrationTests`)
- [ ] 6.6 Wire migration hook into sync path; make tests pass

## 7. LocalFirstNoteSyncService — attachment hydration

- [ ] 7.1 Write failing tests: `hydrateAttachments(noteID:)` downloads missing files; max 3 concurrent; continues after caller cancelled (`AttachmentHydrationTests`)
- [ ] 7.2 Implement hydration actor logic in sync service; make tests pass
- [ ] 7.3 Write failing tests: progress stream emits per-attachment `bytesReceived/totalBytes`; retry single id (`AttachmentHydrationProgressTests`)
- [ ] 7.4 Expose progress + per-id retry API; make tests pass
- [ ] 7.5 Write failing tests: shared note hydration uses `/v1/notes/shared/...` paths (`SharedAttachmentHydrationTests`)
- [ ] 7.6 Implement shared hydration paths; make tests pass

## 8. NotesFlow — save gating and hydration UI

- [ ] 8.1 Write failing tests: `canSave` false when `syncState == pendingSync`; true when synced and dirty (`DefaultNoteDetailViewModelSaveGateTests`)
- [ ] 8.2 Update detail/create view models save gating; make tests pass
- [ ] 8.3 Write failing tests: detail `load()` shows body before attachments; subscribes to hydration progress (`DefaultNoteDetailViewModelHydrationTests`)
- [ ] 8.4 Wire hydration subscription + fast body open in detail VM; make tests pass
- [ ] 8.5 Write failing tests: `NoteAttachmentsSection` shows per-row progress and retry (`NoteAttachmentsSectionProgressTests`)
- [ ] 8.6 Update `NoteAttachmentsSection` + detail/shared views for progress UI; make tests pass
- [ ] 8.7 Write failing tests: shared detail same hydration behavior (`DefaultSharedNoteDetailViewModelHydrationTests`)
- [ ] 8.8 Update shared detail VM; make tests pass

## 9. App composition and cleanup

- [ ] 9.1 Write failing tests: `NotesFlowDependencies` passes hydration/progress source from sync service (`NotesFlowDependenciesSplitTests`)
- [ ] 9.2 Wire dependencies in `AppComposition`; make tests pass
- [ ] 9.3 Write failing tests: dead monolithic note upload paths are not called (`NetworkNoteRepositoryLegacyPathRemovalTests`)
- [ ] 9.4 Remove or no-op legacy `/v1/notes/{id}` content upload/read; make tests pass

## 10. Manual verification

- [ ] 10.1 Create note with attachments → detail opens with text immediately on cold sync → per-attachment progress → preview works
- [ ] 10.2 Leave detail during download → re-open → attachments complete in background
- [ ] 10.3 Save disabled while pending; enabled after synced; edit + save cycles correctly
- [ ] 10.4 Shared note cold open shows same progress behavior
- [ ] 10.5 Legacy local note with inline attachments migrates and reuploads on next sync
