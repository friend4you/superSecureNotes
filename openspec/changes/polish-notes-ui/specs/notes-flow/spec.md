## ADDED Requirements

### Requirement: Note list owned row sync icon trailing

`NoteListView` SHALL display each owned note row with the note title leading and a sync status icon trailing in the same row. The sync indicator SHALL use icon-only display (no text label in the row). Both `.pendingSync` and `.synced` states SHALL show their respective icons. `.pendingDelete` SHALL show no icon.

#### Scenario: Pending sync shows trailing icon

- **WHEN** an owned note row is rendered with `syncState: .pendingSync`
- **THEN** the row shows the note title on the leading side and an orange sync-pending icon on the trailing side without accompanying text

#### Scenario: Synced shows trailing icon

- **WHEN** an owned note row is rendered with `syncState: .synced`
- **THEN** the row shows the note title on the leading side and a secondary synced icon on the trailing side without accompanying text

#### Scenario: Shared rows have no sync icon

- **WHEN** a shared note row is rendered in the Shared segment
- **THEN** no sync status icon is displayed

### Requirement: Note list toolbar layout

`NoteListView` SHALL show a settings toolbar button as a leading `gearshape` icon with no text label, and a create note toolbar button as a trailing primary `plus` icon. The settings and create buttons SHALL be separate toolbar items, not grouped in a menu.

#### Scenario: Settings icon is leading

- **WHEN** `NoteListView` toolbar is rendered
- **THEN** the settings button uses the `gearshape` system image and is placed in a leading toolbar placement

#### Scenario: Create button is trailing primary

- **WHEN** `NoteListView` toolbar is rendered
- **THEN** the create note button uses the `plus` system image in primary trailing placement

#### Scenario: List toolbar has no logout button

- **WHEN** `NoteListView` is rendered in any build configuration
- **THEN** no logout button appears in the list toolbar

### Requirement: Note list opens settings as sheet

`DefaultNoteListViewModel.openSettings()` SHALL present `AuthRoute.settings` with `RoutePresentation.sheet`. It SHALL NOT push the settings route onto the navigation stack.

#### Scenario: Open settings presents sheet

- **WHEN** `openSettings()` is called
- **THEN** `navigator.present(AuthRoute.settings, style: .sheet)` is invoked

### Requirement: Note sync status icon-only display

`NoteSyncStatusLabel` SHALL support an icon-only display mode that renders only the status icon with an accessibility label containing the full pending or synced text. Text labels SHALL NOT be visible in icon-only mode.

#### Scenario: Icon-only pending hides text

- **WHEN** `NoteSyncStatusLabel` is rendered in icon-only mode with `syncState: .pendingSync`
- **THEN** only the pending icon is visible and the accessibility label describes pending sync

#### Scenario: Icon-only synced hides text

- **WHEN** `NoteSyncStatusLabel` is rendered in icon-only mode with `syncState: .synced`
- **THEN** only the synced icon is visible and the accessibility label describes synced state

### Requirement: Note detail form title and principal sync status

`NoteDetailView` SHALL use a static inline navigation title (`notes.detail.title`). The note title SHALL be edited in a form `TextField` section before the body. A full `NoteSyncStatusLabel` (icon and text) SHALL appear in `ToolbarItem(placement: .principal)`. The toolbar SHALL NOT include a separate sync indicator.

#### Scenario: Title is edited in the form

- **WHEN** `NoteDetailView` is rendered after load
- **THEN** an editable `TextField` bound to `viewModel.title` appears in the form and the navigation bar does not bind the note title

#### Scenario: Sync status in principal

- **WHEN** `NoteDetailView` toolbar is rendered for a loaded note
- **THEN** a `NoteSyncStatusLabel` with icon and text appears in `.principal` and no icon-only sync label appears elsewhere in the toolbar

### Requirement: Note detail toolbar actions

`NoteDetailView` SHALL show Save as the primary trailing action and a trailing overflow `Menu` (ellipsis) containing Share and Delete actions. Delete SHALL continue to require a confirmation alert. Share and Delete SHALL NOT appear as standalone toolbar text buttons.

#### Scenario: Overflow menu contains share and delete

- **WHEN** `NoteDetailView` toolbar is rendered
- **THEN** a menu button is present with Share and Delete actions inside it

#### Scenario: Save remains primary action

- **WHEN** `NoteDetailView` toolbar is rendered
- **THEN** Save is the primary trailing toolbar button and is disabled when `!canSave`

### Requirement: Create note inline title and form title field

`CreateNoteView` SHALL use a static inline navigation title (`notes.create.title`) with no `.principal` toolbar item. The note title SHALL be edited in a form `TextField` section before the body.

#### Scenario: Create uses inline screen title only

- **WHEN** `CreateNoteView` is rendered
- **THEN** the navigation bar shows the localized create title inline and has no principal toolbar field

#### Scenario: Create title is edited in the form

- **WHEN** `CreateNoteView` form content is rendered
- **THEN** an editable `TextField` bound to `viewModel.title` appears before the body editor

### Requirement: Shared note detail principal owner and form title

`SharedNoteDetailView` SHALL use a static inline navigation title (`notes.shared.detail.title`). Owner information SHALL appear as text in `ToolbarItem(placement: .principal)` using `notes.shared.detail.ownerCaption`. The note title SHALL appear as read-only text in the form before the body.

#### Scenario: Shared by text in principal

- **WHEN** `SharedNoteDetailView` is rendered after load with owner email
- **THEN** the navigation bar principal shows the localized shared-by caption and not the note title

#### Scenario: Shared title in form

- **WHEN** `SharedNoteDetailView` form content is rendered
- **THEN** the note title appears as read-only `Text(viewModel.title)` before the body

#### Scenario: No sync on shared detail

- **WHEN** `SharedNoteDetailView` is rendered
- **THEN** no sync status indicator is shown

### Requirement: Shared note detail delete overflow menu

`SharedNoteDetailView` SHALL provide a trailing overflow `Menu` containing Delete. Delete SHALL show a confirmation alert before invoking delete. `DefaultSharedNoteDetailViewModel` SHALL implement `delete()` that calls `noteRepository.deleteSharedNote(noteID:)` and pops the navigation stack on success.

#### Scenario: Delete in overflow menu

- **WHEN** `SharedNoteDetailView` toolbar is rendered
- **THEN** a menu button is present with a Delete action and no standalone Delete toolbar button

#### Scenario: Delete pops on success

- **WHEN** the user confirms delete on shared note detail
- **THEN** `deleteSharedNote(noteID:)` is called and `navigator.pop()` is invoked

### Requirement: Note list context menus unchanged

`NoteListView` SHALL retain long-press context menus on owned notes (Share, Delete) and shared notes (Delete) with existing confirmation behavior.

#### Scenario: Owned note context menu preserved

- **WHEN** the user long-presses an owned note row
- **THEN** Share and Delete actions remain available in the context menu

#### Scenario: Shared note context menu preserved

- **WHEN** the user long-presses a shared note row
- **THEN** Delete remains available in the context menu
