## MODIFIED Requirements

### Requirement: ShareNoteViewModel

`ShareNote` SHALL expose a public `@MainActor` `ShareNoteViewModel` protocol conforming to `Observable` with a `noteID` property and a `dismiss()` method. `DefaultShareNoteViewModel` SHALL be the default implementation depending on `Navigating`.

#### Scenario: View model exposes note ID

- **WHEN** `DefaultShareNoteViewModel` is created with a `noteID`
- **THEN** its `noteID` property returns that value

#### Scenario: Dismiss dismisses sheet presentation

- **WHEN** `DefaultShareNoteViewModel.dismiss()` is called
- **THEN** `navigator.dismissPresentation()` is invoked

## ADDED Requirements

### Requirement: NotesFlow presents share as sheet

`NotesFlow` ViewModels SHALL present `ShareNoteRoute.share(noteID:)` using `navigator.present(_, style: .sheet)` from the note list context menu and the note detail share action.

#### Scenario: List share presents sheet

- **WHEN** the user chooses Share from a list item context menu
- **THEN** `navigator.present(ShareNoteRoute.share(noteID:), style: .sheet)` is called with that note's ID

#### Scenario: Detail share presents sheet

- **WHEN** the user taps Share on the note detail screen
- **THEN** `navigator.present(ShareNoteRoute.share(noteID:), style: .sheet)` is called with the detail note ID
