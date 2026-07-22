## 1. Package Structure

- [x] 1.1 Create `Packages/NotesFlow/Package.swift` with `NotesFlow` library product/target (platforms: iOS 17+, macOS 13+; no package dependencies)
- [x] 1.2 Scaffold `Sources/NotesFlow/` module entry point
- [x] 1.3 Add `NotesFlow` local package reference to Xcode project (app target only)

## 2. NoteListView Placeholder

- [x] 2.1 Write failing test: `NoteListView()` is publicly constructible when importing `NotesFlow` (`NotesFlowTests/NoteListViewTests.swift` — scenario: NoteListView is publicly constructible)
- [x] 2.2 Add public `NoteListView` with `Text("Note list")` and `#Preview`; make constructibility test pass
- [x] 2.3 Verify `#Preview` for `NoteListView` compiles in Xcode (scenario: NoteListView preview compiles)

## 3. App Integration

- [x] 3.1 Link `NotesFlow` product to `superSecureNotes` app target only (scenario: App target links NotesFlow)
- [x] 3.2 Update app root (`ContentView` or `superSecureNotesApp`) to `import NotesFlow` and present `NoteListView` (scenario: App presents NoteListView)
- [x] 3.3 Build and run app; confirm `"Note list"` is visible (scenario: NoteListView shows placeholder label)

## 4. Verification

- [x] 4.1 Verify `NotesFlow` package builds with no imports of `SecureCrypto` or `VaultSession` (scenario: Package has no internal project dependencies)
- [x] 4.2 Run `NotesFlowTests`; confirm all tests pass
