## 1. Manifest models and fixtures

- [ ] 1.1 Write failing tests: `AttachmentSummaryResponseDTO` and `RemoteAttachmentSummary` decode/include `totalChunks` and `chunkSize`; `attachmentsManifestJSON` fixture includes chunk fields (`NoteAPIClientAttachmentTests` or new manifest tests)
- [ ] 1.2 Add chunk fields to DTO, `RemoteAttachmentSummary`, and `decodeAttachmentManifest`; update `NoteFixtures.attachmentsManifestJSON`; make tests pass

## 2. Attachment chunk download API client

- [ ] 2.1 Write failing tests: owner `readAttachmentChunk` sends `GET .../attachments/{id}/chunks/{index}` and returns chunk bytes; shared `readSharedAttachmentChunk` uses shared path (`NoteAPIClientAttachmentChunkDownloadTests`)
- [ ] 2.2 Implement `readAttachmentChunk` and `readSharedAttachmentChunk` on `NoteAPIClient`; make tests pass
- [ ] 2.3 Write failing tests: remove or replace `readAttachment` / `readSharedAttachment` blob GET tests — chunk methods are the only download paths (`NoteAPIClientAttachmentTests`)
- [ ] 2.4 Remove full-blob `readAttachment` and `readSharedAttachment` from `NoteAPIClient`; make tests pass

## 3. NetworkNoteRepository chunk download

- [ ] 3.1 Write failing tests: `readAttachment` loops `0..<totalChunks`, concatenates chunks, returns full ciphertext; `readSharedAttachment` uses shared chunk path (`NetworkNoteRepositoryChunkDownloadTests`)
- [ ] 3.2 Implement chunk download + concat in `NetworkNoteRepository`; accept manifest summary or list internally; make tests pass

## 4. Uniform chunked upload — remove size branch

- [ ] 4.1 Write failing tests: attachment upload always uses init → chunks → complete for 2048-byte ciphertext; no `PUT .../attachments/{id}` (`NetworkNoteRepositorySplitUploadTests` — flip `testUploadNoteUsesSingleAttachmentPUTAtThreshold`)
- [ ] 4.2 Remove `NoteUploadSizeThreshold` branch in `uploadAttachment`; always call `uploadAttachmentChunked`; make tests pass
- [ ] 4.3 Write failing tests: init request body includes `contentType: application/octet-stream` (`NoteAPIClientAttachmentChunkedUploadTests`)
- [ ] 4.4 Add `contentType` to `initAttachmentUpload` JSON body; make tests pass
- [ ] 4.5 Write failing tests: remove `writeAttachment` usage — delete or repurpose `NoteAPIClientAttachmentTests` write tests
- [ ] 4.6 Remove `writeAttachment` from `NoteAPIClient`; make tests pass

## 5. Hydration — chunk download and incremental progress

- [ ] 5.1 Write failing tests: hydration mocks chunk GET paths (not full blob GET) for owner and shared; concatenated file written locally (`AttachmentHydrationTests`, `SharedAttachmentHydrationTests`)
- [ ] 5.2 Update hydration tests fixtures for manifest with `totalChunks`/`chunkSize`; make stub handlers return chunks
- [ ] 5.3 Write failing tests: progress events increment as each chunk completes (not only 0 → 100%) (`AttachmentHydrationProgressTests`)
- [ ] 5.4 Wire incremental progress in `downloadOneAttachment` via repository chunk callbacks or byte accumulation; make tests pass

## 6. Test sweep and legacy removal

- [ ] 6.1 Write failing tests: no test or production code calls `PUT` or full-blob `GET` on `/attachments/{id}` without `/uploads` or `/chunks/` (`NetworkNoteRepositoryLegacyPathRemovalTests` extension)
- [ ] 6.2 Update remaining split upload tests, sync session tests, and fixtures that stub PUT/GET blob paths; make tests pass

## 7. Manual verification

- [ ] 7.1 With API on `:8000` after server migration: upload 2 KB attachment → sync completes → download/hydrate → preview works
- [ ] 7.2 Upload attachment > 5 MB → multi-chunk upload and download complete
- [ ] 7.3 Shared note: chunk download after share grant shows progress and preview works
