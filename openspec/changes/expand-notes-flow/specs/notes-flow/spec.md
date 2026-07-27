## MODIFIED Requirements

### Requirement: NoteListView placeholder screen

The module SHALL expose a public SwiftUI view `NoteListView` that accepts a `DefaultNoteListViewModel` via initializer. The view SHALL display a list of notes with titles loaded from the view model, inline loading and error text, pull-to-refresh, a create toolbar button, a settings toolbar button with no action and a `TODO` comment in code, and a DEBUG-only logout button. The view SHALL NOT display the placeholder text `"Note list"` as primary content.

#### Scenario: NoteListView shows note titles

- **WHEN** `NoteListView` is rendered with a view model containing note summaries
- **THEN** each note title is visible in the list

#### Scenario: DEBUG build shows logout button

- **WHEN** `NoteListView` is rendered in a DEBUG build
- **THEN** a logout control is visible in the toolbar

#### Scenario: Release build hides logout button

- **WHEN** `NoteListView` is rendered in a Release build
- **THEN** no logout control is present

## ADDED Requirements

### Requirement: NotesFlow localization

The `NotesFlow` package SHALL set `defaultLocalization: "en"`, include a `Localizable.xcstrings` resource catalog, and expose a localization helper using `bundle: .module` for all user-visible strings on notes screens.

#### Scenario: String catalog is bundled

- **WHEN** `NotesFlow` tests run
- **THEN** the localized string catalog is present in the module bundle

#### Scenario: List navigation title is localized

- **WHEN** `NoteListView` is rendered
- **THEN** its navigation title uses a localized string key, not a hardcoded English literal in source

### Requirement: NotesFlow package dependencies

The `NotesFlow` target SHALL depend on `NoteRepositoryProtocol`, `SecureCrypto`, and `ShareNoteRoutes` in addition to existing dependencies. It SHALL NOT depend on the `NoteRepository` implementation target or `ShareNote` UI target.

#### Scenario: NotesFlow compiles with note and crypto protocols

- **WHEN** the `NotesFlow` package is built
- **THEN** it links `NoteRepositoryProtocol`, `SecureCrypto`, and `ShareNoteRoutes`

### Requirement: NotesDependencyProviding note repository factory

`NotesDependencyProviding` SHALL be extended with factory methods `makeNoteListViewModel()`, `makeNoteDetailViewModel(noteID:)`, and `makeCreateNoteViewModel()`. `NotesFlowDependencies` SHALL accept `noteRepository: any NoteRepository` and pass it to all note view models.

#### Scenario: Dependencies produce detail view model with note ID

- **WHEN** `makeNoteDetailViewModel(noteID: id)` is called on `NotesFlowDependencies`
- **THEN** a `DefaultNoteDetailViewModel` bound to `id` is returned

#### Scenario: Dependencies produce create view model

- **WHEN** `makeCreateNoteViewModel()` is called on `NotesFlowDependencies`
- **THEN** a `DefaultCreateNoteViewModel` is returned

### Requirement: NoteListViewModel list behavior

`NotesFlow` SHALL define `NoteListViewModel` and `DefaultNoteListViewModel` that load notes via `noteRepository.listNotes()`, sort by `updatedAt` descending, support `refresh()`, expose loading and error state, and navigate via `Navigating`.

#### Scenario: Refresh loads notes

- **WHEN** `refresh()` is called
- **THEN** `noteRepository.listNotes()` is invoked and published notes reflect the response sorted by `updatedAt` descending

#### Scenario: Open detail pushes route

- **WHEN** `openDetail(noteID: id)` is called
- **THEN** `navigator.push(NotesRoute.detail(noteID: id))` is invoked

#### Scenario: Create note pushes route

- **WHEN** `createNote()` is called
- **THEN** `navigator.push(NotesRoute.create)` is invoked

#### Scenario: Share presents sheet

- **WHEN** `share(noteID: id)` is called
- **THEN** `navigator.present(ShareNoteRoute.share(noteID: id), style: .sheet)` is invoked

#### Scenario: Delete removes note after confirmation

- **WHEN** `deleteNote(noteID: id)` is called
- **THEN** `noteRepository.deleteNote(noteID: id)` is invoked and the list is refreshed

### Requirement: NoteListView list interactions

`NoteListView` SHALL support pull-to-refresh calling `viewModel.refresh()`, context menu on each row with Share and Delete actions, and a confirmation alert before Delete. Share from the context menu SHALL call `viewModel.share(noteID:)`. Delete confirmation SHALL call `viewModel.deleteNote(noteID:)`.

#### Scenario: Pull to refresh triggers reload

- **WHEN** the user pulls to refresh on the list
- **THEN** `viewModel.refresh()` is called

#### Scenario: Context menu offers share and delete

- **WHEN** the user opens the context menu on a list row
- **THEN** Share and Delete actions are available

#### Scenario: Delete shows confirmation

- **WHEN** the user chooses Delete from the context menu
- **THEN** a confirmation alert is shown before delete proceeds

### Requirement: NoteListView inline loading and error

`NoteListView` SHALL display inline loading indicator while `viewModel.isLoading` is true and inline error text when `viewModel.errorMessage` is non-nil.

#### Scenario: Loading state visible

- **WHEN** the view model is loading
- **THEN** a loading indicator is shown inline in the list screen

#### Scenario: Error message visible

- **WHEN** the view model has an error message
- **THEN** the error text is displayed inline on the list screen

### Requirement: NoteListView settings stub button

`NoteListView` SHALL include a settings toolbar button whose action is empty and contains a source-code `TODO` comment for future settings navigation. The button SHALL perform no navigation or side effects.

#### Scenario: Settings button has no action

- **WHEN** the user taps the settings toolbar button
- **THEN** no navigation occurs and no repository or session APIs are called

### Requirement: NoteDetailViewModel load and save

`NotesFlow` SHALL provide `NoteDetailViewModel` and `DefaultNoteDetailViewModel` that load a note by ID, decrypt content using `VaultSession.udk()` and `SecureCrypto` note APIs, expose editable title and body strings, attachment filename list, `hasChanges`, `canSave`, loading and error state, and save via `writeNote`.

#### Scenario: Load decrypts note content

- **WHEN** `load()` is called for a stored note
- **THEN** `readNote` is called, the blob is parsed and decrypted, and title and body fields are populated

#### Scenario: Save writes encrypted blob

- **WHEN** `save()` is called with valid changes and non-empty title
- **THEN** a new `.note` blob is assembled and `writeNote(noteID:data:)` is called

#### Scenario: Can save requires changes and title

- **WHEN** title is empty or there are no changes from loaded state
- **THEN** `canSave` is false

#### Scenario: Can save when title non-empty and dirty

- **WHEN** title is non-empty and fields differ from loaded state
- **THEN** `canSave` is true

### Requirement: NoteDetailView editing UI

`NoteDetailView` SHALL display localized navigation title, `TextField` for title, `TextEditor` for body UTF-8 text, a list of attachment filenames, inline loading and error text, a Save toolbar button disabled when `!viewModel.canSave`, a Share toolbar button, and a Delete action with confirmation alert.

#### Scenario: Save button disabled when cannot save

- **WHEN** `viewModel.canSave` is false
- **THEN** the Save button is disabled

#### Scenario: Share button presents sheet

- **WHEN** the user taps Share
- **THEN** `viewModel.share()` is called

#### Scenario: Delete shows confirmation

- **WHEN** the user chooses Delete on the detail screen
- **THEN** a confirmation alert is shown before delete proceeds

### Requirement: NoteDetailViewModel delete

`DefaultNoteDetailViewModel` SHALL delete the note via `noteRepository.deleteNote` after user confirmation and pop navigation on success.

#### Scenario: Delete pops on success

- **WHEN** `delete()` completes successfully after confirmation
- **THEN** `navigator.pop()` is invoked

### Requirement: CreateNoteViewModel create flow

`NotesFlow` SHALL provide `CreateNoteViewModel` and `DefaultCreateNoteViewModel` with editable title and body, attachment collection, `canSave` (non-empty title and at least one field dirty), loading and error state, and `save()` that creates a new note with a generated UUID, encrypts content, writes via `writeNote`, and pops.

#### Scenario: Save creates new note and pops

- **WHEN** `save()` is called with non-empty title
- **THEN** a new note ID is generated, encrypted blob is written, and `navigator.pop()` is called

#### Scenario: Can save requires non-empty title and changes

- **WHEN** title is empty
- **THEN** `canSave` is false

#### Scenario: Can save with title and any content

- **WHEN** title is non-empty and title, body, or attachments differ from initial empty state
- **THEN** `canSave` is true

### Requirement: CreateNoteView attachment pickers

`CreateNoteView` SHALL provide `PhotosPicker` for images and `fileImporter` for common types (images, PDF, plain text), display selected attachment filenames, a Save button gated by `canSave`, inline loading and error text, and localized labels.

#### Scenario: Photos picker adds attachment

- **WHEN** the user selects an image from the photo picker
- **THEN** an attachment entry is added to the view model

#### Scenario: File importer adds attachment

- **WHEN** the user selects a file via the file importer
- **THEN** an attachment entry is added to the view model

### Requirement: NotesNavigation maps all routes

`NotesNavigation.view(for:deps:)` SHALL map `.list` to `NoteListView`, `.detail(noteID:)` to `NoteDetailView`, and `.create` to `CreateNoteView`.

#### Scenario: Detail route builds NoteDetailView

- **WHEN** `NotesNavigation.view(for: .detail(noteID: id), deps:)` is called
- **THEN** a `NoteDetailView` for `id` is produced

#### Scenario: Create route builds CreateNoteView

- **WHEN** `NotesNavigation.view(for: .create, deps:)` is called
- **THEN** a `CreateNoteView` is produced

### Requirement: Note detail inline loading and error

`NoteDetailView` and `CreateNoteView` SHALL show inline loading while the view model is loading and inline error text when `errorMessage` is set.

#### Scenario: Detail shows load error inline

- **WHEN** detail load fails
- **THEN** error text is shown inline on the detail screen

#### Scenario: Create shows save error inline

- **WHEN** create save fails
- **THEN** error text is shown inline on the create screen
