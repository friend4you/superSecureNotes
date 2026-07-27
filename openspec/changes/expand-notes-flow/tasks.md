## 1. FileNoteRepository stub

- [ ] 1.1 Write failing tests: `FileNoteRepository` write/read roundtrip, `listNotes` from stored files, `deleteNote` removes file, `readNote` throws `noteNotFound` when missing (`superSecureNotesTests/FileNoteRepositoryTests.swift`)
- [ ] 1.2 Implement `FileNoteRepository` actor in `superSecureNotes/Stub/FileNoteRepository.swift`; make tests pass

## 2. App — note repository wiring

- [ ] 2.1 Write failing tests: stub mode selects `FileNoteRepository`, network mode selects `NetworkNoteRepository` (`superSecureNotesTests/AppDependenciesTests.swift`)
- [ ] 2.2 Add `noteRepository` to `AppDependencies` with conditional construction; make tests pass
- [ ] 2.3 Write failing test: `AppComposition` passes `noteRepository` to `NotesFlowDependencies` (`superSecureNotesTests/AppCompositionTests.swift`)
- [ ] 2.4 Wire `noteRepository` in `AppComposition`; link `NoteRepository` product if needed; make test pass

## 3. NotesFlowRoutes — new route cases

- [ ] 3.1 Write failing tests: `NotesRoute` includes `.detail(noteID: UUID)` and `.create`; both are `Hashable` and `Sendable` (`NotesFlowRoutesTests/NotesRouteTests.swift`)
- [ ] 3.2 Add route cases to `NotesRoute.swift`; make tests pass

## 4. NotesFlow — package dependencies and localization

- [ ] 4.1 Add `NoteRepository`, `SecureCrypto`, and `ShareNoteRoutes` package dependencies to `NotesFlow/Package.swift`; add `NoteRepositoryProtocol`, `SecureCrypto`, `ShareNoteRoutes` to `NotesFlow` target; set `defaultLocalization: "en"`
- [ ] 4.2 Add `Resources/Localizable.xcstrings`, `NotesFlowUILocalization.swift`, and `NotesFlowUIBundleTesting.swift`
- [ ] 4.3 Write failing test: string catalog is bundled (`NotesFlowTests/Localization/LocalizationTests.swift`)
- [ ] 4.4 Verify localization helper and catalog; make test pass

## 5. NotesFlow — dependency injection

- [ ] 5.1 Write failing tests: `NotesFlowDependencies` accepts `noteRepository`; `makeNoteDetailViewModel(noteID:)` and `makeCreateNoteViewModel()` return expected types (`NotesFlowTests/NotesFlowDependenciesTests.swift`)
- [ ] 5.2 Extend `NotesDependencyProviding` and `NotesFlowDependencies` with `noteRepository` and new factory methods; make tests pass

## 6. NoteListViewModel

- [ ] 6.1 Write failing tests: `refresh()` calls `listNotes` and sorts by `updatedAt`; `openDetail` pushes `.detail`; `createNote` pushes `.create`; `share` presents sheet; `deleteNote` calls repository (`NotesFlowTests/DefaultNoteListViewModelTests.swift`)
- [ ] 6.2 Implement `NoteListViewModel` protocol and expand `DefaultNoteListViewModel` with notes state, loading, error, and navigation methods; make tests pass

## 7. NoteListView

- [ ] 7.1 Write failing tests: list renders titles from view model; pull-to-refresh calls `refresh`; context menu Share/Delete; delete confirmation; settings button has no side effects (`NotesFlowTests/NoteListViewTests.swift` or ViewInspector-style VM tests where layout tests are impractical — prefer VM tests for delete/share callbacks)
- [ ] 7.2 Implement `NoteListView` with `List`, refreshable, context menu, alerts, create/settings/logout toolbar items, inline loading/error; localized strings; make tests pass
- [ ] 7.3 Update `NotesNavigation.listView(deps:)` if needed

## 8. NoteDetailViewModel

- [ ] 8.1 Write failing tests: `load()` decrypts note; `save()` writes blob; `canSave` gating; `share()` presents sheet; `delete()` calls repository and pops (`NotesFlowTests/DefaultNoteDetailViewModelTests.swift`)
- [ ] 8.2 Implement `NoteDetailViewModel` and `DefaultNoteDetailViewModel` with SecureCrypto orchestration; make tests pass

## 9. NoteDetailView

- [ ] 9.1 Write failing tests: Save disabled when `!canSave`; Share calls view model; Delete shows confirmation (`NotesFlowTests/NoteDetailViewTests.swift` — VM seam tests acceptable per development-practices)
- [ ] 9.2 Implement `NoteDetailView` with title field, body editor, attachment list, Save/Share/Delete UI, inline loading/error; localized strings; make tests pass

## 10. CreateNoteViewModel

- [ ] 10.1 Write failing tests: `canSave` requires non-empty title and changes; `addAttachment`/`removeAttachment`; `save()` writes new note and pops (`NotesFlowTests/DefaultCreateNoteViewModelTests.swift`)
- [ ] 10.2 Implement `CreateNoteViewModel` and `DefaultCreateNoteViewModel` with crypto orchestration for new notes; make tests pass

## 11. CreateNoteView

- [ ] 11.1 Write failing tests: Save gated by `canSave`; photo and file selection add attachments (`NotesFlowTests/CreateNoteViewTests.swift` — VM seam tests)
- [ ] 11.2 Implement `CreateNoteView` with `PhotosPicker`, `fileImporter`, attachment list, Save button, inline loading/error; localized strings; make tests pass

## 12. NotesNavigation

- [ ] 12.1 Write failing tests: `view(for: .detail(noteID:), deps:)` returns `NoteDetailView`; `view(for: .create, deps:)` returns `CreateNoteView` (`NotesFlowTests/Navigation/NotesNavigationTests.swift`)
- [ ] 12.2 Extend `NotesNavigation.view(for:deps:)` for detail and create routes; make tests pass

## 13. ShareNote dismiss fix

- [ ] 13.1 Write failing test: `DefaultShareNoteViewModel.dismiss()` calls `dismissPresentation()` instead of `pop()` (`ShareNoteTests/ShareNoteTests.swift`)
- [ ] 13.2 Update `DefaultShareNoteViewModel.dismiss()`; make test pass

## 14. Integration and verification

- [ ] 14.1 Write failing integration test: list → detail navigation via registry (`superSecureNotesTests/AppCompositionTests.swift` or `NotesNavigationTests`)
- [ ] 14.2 Verify route registry resolves new `NotesRoute` cases; make test pass
- [ ] 14.3 Run full test suite; fix regressions
- [ ] 14.4 Manual smoke with `-UseStubBackend`: create note → appears in list → open detail → edit save → share sheet → delete from detail and list
