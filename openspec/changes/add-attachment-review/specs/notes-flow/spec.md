## MODIFIED Requirements

### Requirement: NoteDetailViewModel load and save

`NotesFlow` SHALL provide `NoteDetailViewModel` and `DefaultNoteDetailViewModel` that load a note by ID, decrypt content using `VaultSession.udk()` and `SecureCrypto` note APIs, expose editable title and body strings, `attachmentItems` (`NoteAttachmentItem` with id, filename, mime), `hasChanges`, `canSave`, loading and error state, `addAttachment`, `removeAttachment(id:)`, `attachmentData(for:)`, and save via `writeNote`.

#### Scenario: Load decrypts note content

- **WHEN** `load()` is called for a stored note
- **THEN** `readNote` is called, the blob is parsed and decrypted, and title, body, and attachment items are populated

#### Scenario: Save writes encrypted blob

- **WHEN** `save()` is called with valid changes and non-empty title
- **THEN** a new `.note` blob is assembled with the current attachment collection and `writeNote(noteID:data:)` is called

#### Scenario: Can save requires changes and title

- **WHEN** title is empty or there are no changes from loaded state
- **THEN** `canSave` is false

#### Scenario: Can save when title non-empty and dirty

- **WHEN** title is non-empty and title, body, or attachments differ from loaded state
- **THEN** `canSave` is true

#### Scenario: Add attachment marks detail dirty

- **WHEN** `addAttachment` is called after load
- **THEN** `attachmentItems` includes the new item and `hasChanges` is true

#### Scenario: Remove attachment marks detail dirty

- **WHEN** `removeAttachment(id:)` is called for an existing attachment after load
- **THEN** the attachment is removed from `attachmentItems` and `hasChanges` is true

#### Scenario: Attachment data available for preview

- **WHEN** `attachmentData(for:)` is called with a valid attachment id
- **THEN** the attachment byte content is returned

### Requirement: NoteDetailView editing UI

`NoteDetailView` SHALL display localized navigation title, `TextField` for title, `TextEditor` for body UTF-8 text, a shared attachment section with rows (filename, trash button, tap-to-preview), `PhotosPicker` and `fileImporter` for common types (images, PDF, plain text), inline loading and error text, a Save toolbar button disabled when `!viewModel.canSave`, a Share toolbar button, and a Delete action with confirmation alert.

#### Scenario: Save button disabled when cannot save

- **WHEN** `viewModel.canSave` is false
- **THEN** the Save button is disabled

#### Scenario: Share button presents sheet

- **WHEN** the user taps Share
- **THEN** `viewModel.share()` is called

#### Scenario: Delete shows confirmation

- **WHEN** the user chooses Delete on the detail screen
- **THEN** a confirmation alert is shown before delete proceeds

#### Scenario: Trash removes attachment

- **WHEN** the user taps the trash button on an attachment row
- **THEN** `viewModel.removeAttachment(id:)` is called for that attachment

#### Scenario: Tap opens preview

- **WHEN** the user taps an attachment row on iOS
- **THEN** a QuickLook preview is presented for that attachment

### Requirement: CreateNoteViewModel create flow

`NotesFlow` SHALL provide `CreateNoteViewModel` and `DefaultCreateNoteViewModel` with editable title and body, `attachmentItems`, `addAttachment`, `removeAttachment(id:)`, `attachmentData(for:)`, `canSave` (non-empty title and at least one field dirty), loading and error state, and `save()` that creates a new note with a generated UUID, encrypts content, writes via `writeNote`, and pops.

#### Scenario: Save creates new note and pops

- **WHEN** `save()` is called with non-empty title
- **THEN** a new note ID is generated, encrypted blob is written, and `navigator.pop()` is called

#### Scenario: Can save requires non-empty title and changes

- **WHEN** title is empty
- **THEN** `canSave` is false

#### Scenario: Can save with title and any content

- **WHEN** title is non-empty and title, body, or attachments differ from initial empty state
- **THEN** `canSave` is true

#### Scenario: Remove attachment updates items

- **WHEN** `removeAttachment(id:)` is called
- **THEN** the attachment is removed from `attachmentItems`

### Requirement: CreateNoteView attachment pickers

`CreateNoteView` SHALL provide `PhotosPicker` for images and `fileImporter` for common types (images, PDF, plain text), display attachments via the shared attachment section (filename, trash button, tap-to-preview on iOS), a Save button gated by `canSave`, inline loading and error text, and localized labels.

#### Scenario: Photos picker adds attachment

- **WHEN** the user selects an image from the photo picker
- **THEN** an attachment entry is added to the view model

#### Scenario: File importer adds attachment

- **WHEN** the user selects a file via the file importer
- **THEN** an attachment entry is added to the view model

#### Scenario: Trash removes attachment

- **WHEN** the user taps the trash button on an attachment row
- **THEN** `viewModel.removeAttachment(id:)` is called for that attachment

#### Scenario: Tap opens preview

- **WHEN** the user taps an attachment row on iOS
- **THEN** a QuickLook preview is presented for that attachment

## ADDED Requirements

### Requirement: NoteAttachmentItem display model

`NotesFlow` SHALL define a public `NoteAttachmentItem` type with `id: String`, `filename: String`, and `mime: String` used by create and detail ViewModels for attachment list UI.

#### Scenario: Items expose stable identity

- **WHEN** a view model publishes attachment items
- **THEN** each item has a unique `id` suitable for list iteration

### Requirement: Shared NoteAttachmentsSection

`NotesFlow` SHALL provide a shared SwiftUI `NoteAttachmentsSection` used by `CreateNoteView` and `NoteDetailView` that renders attachment rows with localized filename label, trash remove button, and tap-to-preview on iOS.

#### Scenario: Section hidden when empty

- **WHEN** the view model has no attachment items
- **THEN** the attachment section is not shown

#### Scenario: Section shows all items

- **WHEN** the view model has attachment items
- **THEN** each item appears as one row with filename and trash button

### Requirement: iOS QuickLook attachment preview

On iOS, `NotesFlow` SHALL provide a QuickLook-based preview that writes attachment bytes to a temporary file, presents `QLPreviewController`, and deletes the temporary file when the preview is dismissed.

#### Scenario: Preview presents QuickLook

- **WHEN** preview is requested for attachment data and filename
- **THEN** a QuickLook preview controller is shown with that content

#### Scenario: Temp file cleaned up

- **WHEN** the preview is dismissed
- **THEN** the temporary preview file is deleted

### Requirement: Attachment action localization

All user-visible strings for attachment preview, remove, and section labels SHALL use the `NotesFlow` localization helper and string catalog.

#### Scenario: Attachment strings are localized

- **WHEN** `NotesFlow` tests run
- **THEN** localization keys exist for attachment section title, remove action, and preview-related labels
