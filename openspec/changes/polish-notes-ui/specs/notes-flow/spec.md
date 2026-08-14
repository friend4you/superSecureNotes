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

### Requirement: Note detail editable navigation title

`NoteDetailView` SHALL bind the note title to an editable `TextField` in the navigation bar (`.principal` placement with inline display mode). The form SHALL NOT include a separate title section. The body editor SHALL be the first content section after loading/error states.

#### Scenario: Title is edited in navigation bar

- **WHEN** `NoteDetailView` is rendered after load
- **THEN** the navigation bar contains an editable text field bound to `viewModel.title` and no title `TextField` appears in the form body

#### Scenario: Body section follows without title section

- **WHEN** `NoteDetailView` form content is rendered
- **THEN** the body `TextEditor` is not preceded by a dedicated title form section

### Requirement: Note detail toolbar actions

`NoteDetailView` SHALL show Save as the primary trailing action, a trailing icon-only sync status indicator, and a trailing overflow `Menu` (ellipsis) containing Share and Delete actions. Delete SHALL continue to require a confirmation alert. Share and Delete SHALL NOT appear as standalone toolbar text buttons.

#### Scenario: Overflow menu contains share and delete

- **WHEN** `NoteDetailView` toolbar is rendered
- **THEN** a menu button is present with Share and Delete actions inside it

#### Scenario: Save remains primary action

- **WHEN** `NoteDetailView` toolbar is rendered
- **THEN** Save is the primary trailing toolbar button and is disabled when `!canSave`

#### Scenario: Sync icon in toolbar

- **WHEN** `NoteDetailView` toolbar is rendered for a loaded note
- **THEN** an icon-only `NoteSyncStatusLabel` appears in the trailing toolbar area

### Requirement: Create note editable navigation title

`CreateNoteView` SHALL bind the note title to an editable `TextField` in the navigation bar using the same pattern as `NoteDetailView`. The form SHALL NOT include a separate title section.

#### Scenario: Create title is edited in navigation bar

- **WHEN** `CreateNoteView` is rendered
- **THEN** the navigation bar contains an editable text field bound to `viewModel.title` and no title `TextField` appears in the form body

### Requirement: Shared note detail navigation title and owner metadata

`SharedNoteDetailView` SHALL display the note title in the navigation bar as read-only text. Owner information SHALL appear as a single caption-style line above the body using tertiary foreground styling, without a "Shared by" form section header.

#### Scenario: Shared title in navigation bar

- **WHEN** `SharedNoteDetailView` is rendered after load
- **THEN** the navigation bar shows the note title as read-only text, not the generic "Shared Note" label as the principal title

#### Scenario: Owner metadata is de-emphasized

- **WHEN** `SharedNoteDetailView` renders owner email
- **THEN** it appears as caption-style text above the body without a form section header titled "Shared by"

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
