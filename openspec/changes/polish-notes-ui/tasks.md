## 1. NoteSyncStatusLabel icon-only mode

- [x] 1.1 Write failing tests: icon-only mode hides text labels for pending and synced states; accessibility labels retain full descriptions; pendingDelete renders empty (`NotesFlowTests/NoteSyncStatusLabelTests.swift`)
- [x] 1.2 Add icon-only display parameter to `NoteSyncStatusLabel`; make tests pass

## 2. Note list view model — settings sheet

- [x] 2.1 Write failing test: `openSettings()` presents `AuthRoute.settings` with `.sheet` instead of push (`NotesFlowTests/DefaultNoteListViewModelTests.swift`)
- [x] 2.2 Update `DefaultNoteListViewModel.openSettings()` to use `present(..., style: .sheet)`; make test pass

## 3. Note list view — row layout and toolbar

- [x] 3.1 Write failing tests: owned row source uses trailing icon-only sync; shared row has no sync; toolbar uses `gearshape` leading and `plus` trailing; no logout button in any build (`NotesFlowTests/NoteListViewTests.swift`)
- [x] 3.2 Refactor `NoteListView` owned rows to `HStack` with trailing `NoteSyncStatusLabel` icon-only; update toolbar icons and placements; remove logout toolbar item and `#if DEBUG`; make tests pass

## 4. Note detail view — navigation title and overflow menu

- [x] 4.1 Write failing tests: editable title in `.principal` TextField; no title form section; sync icon in toolbar; `Menu` with Share and Delete; no standalone Share/Delete toolbar buttons (`NotesFlowTests/NoteDetailViewTests.swift`)
- [x] 4.2 Refactor `NoteDetailView`: nav title field, remove title/sync form sections, toolbar Save + sync icon + overflow menu; make tests pass

## 5. Create note view — navigation title

- [x] 5.1 Write failing tests: editable title in navigation bar; no title form section (`NotesFlowTests/CreateNoteViewTests.swift`)
- [x] 5.2 Refactor `CreateNoteView` to match detail nav title pattern; remove title section; make tests pass

## 6. Shared note detail — layout and delete

- [x] 6.1 Write failing tests: `DefaultSharedNoteDetailViewModel.delete()` calls `deleteSharedNote` and pops; view source has read-only nav title, caption owner metadata, overflow Delete menu, no sync (`NotesFlowTests/SharedNoteDetailTests.swift` and view source tests)
- [x] 6.2 Add `delete()` to `SharedNoteDetailViewModel` protocol and `DefaultSharedNoteDetailViewModel`; make VM tests pass
- [x] 6.3 Refactor `SharedNoteDetailView`: read-only nav title, de-emphasized owner line, overflow Delete with confirmation alert; make view tests pass

## 7. Auth settings — sheet chrome and logout

- [x] 7.1 Write failing tests: settings view wrapped in `NavigationStack` with Done dismiss; logout button present without `#if DEBUG`; logout calls `performLogout` (`AuthFlowUITests/Views/BiometricSettingsViewTests.swift`, `AuthFlowProtocolTests/ViewModels/BiometricSettingsViewModelTests.swift`)
- [x] 7.2 Extend `DefaultBiometricSettingsViewModel` with `performLogout` and `logout()`; update `AuthFlowDependencyProviding` and `AuthFlowDependencies` factory; wire `performLogout` from `AppComposition`; make tests pass
- [x] 7.3 Wrap `BiometricSettingsView` in `NavigationStack` with Done toolbar button and logout section; update `AuthNavigation.settingsView` if needed; make tests pass

## 8. Integration verification

- [x] 8.1 Run `NotesFlow` and `AuthFlow` test targets; fix any regressions in `NoteDetailViewTests`, `DefaultNoteListViewModelTests`, and navigation tests expecting settings push

## 9. Detail layout refinement — form title and principal metadata

- [x] 9.1 Update `NoteDetailView`: form title field, full sync status in `.principal`, remove toolbar sync icon; update `NoteDetailViewTests`
- [x] 9.2 Update `SharedNoteDetailView`: shared-by text in `.principal`, read-only title in form; update `SharedNoteDetailTests`
- [x] 9.3 Update `CreateNoteView`: inline static nav title only, form title field; update `CreateNoteViewTests`
- [x] 9.4 Update `polish-notes-ui` proposal, design, and `notes-flow` spec for form-title + principal-metadata layout
