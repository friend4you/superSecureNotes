## ADDED Requirements

### Requirement: ShareNoteDependencyProviding protocol

`ShareNote` SHALL expose a public `@MainActor` protocol `ShareNoteDependencyProviding` for dependencies required by share screens. Concrete implementations SHALL NOT be public from the `ShareNote` package.

#### Scenario: Protocol is public

- **WHEN** a consumer imports `ShareNote`
- **THEN** `ShareNoteDependencyProviding` is accessible

#### Scenario: Protocol provides share view model factory

- **WHEN** `ShareNoteDependencyProviding` is defined
- **THEN** it includes a `makeShareNoteViewModel(noteID:)` method returning `DefaultShareNoteViewModel`

### Requirement: ShareNoteViewModel

`ShareNote` SHALL expose a public `@MainActor` `ShareNoteViewModel` protocol conforming to `Observable` with a `noteID` property and a `dismiss()` method. `DefaultShareNoteViewModel` SHALL be the default implementation depending on `Navigating`.

#### Scenario: View model exposes note ID

- **WHEN** `DefaultShareNoteViewModel` is created with a `noteID`
- **THEN** its `noteID` property returns that value

#### Scenario: Dismiss pops navigation stack

- **WHEN** `DefaultShareNoteViewModel.dismiss()` is called
- **THEN** `navigator.pop()` is invoked

### Requirement: ShareNoteView placeholder screen

`ShareNote` SHALL provide a public `ShareNoteView` that displays placeholder text `"Share note"` and accepts a `DefaultShareNoteViewModel` via init.

#### Scenario: Share view shows placeholder

- **WHEN** `ShareNoteView` is rendered
- **THEN** it displays the text `"Share note"`

### Requirement: ShareNoteNavigation view builder

`ShareNote` SHALL provide a `ShareNoteNavigation` type with a static `view(for:deps:)` method that maps each `ShareNoteRoute` case to the corresponding SwiftUI screen using `any ShareNoteDependencyProviding`.

#### Scenario: Share route builds ShareNoteView

- **WHEN** `ShareNoteNavigation.view(for: .share(noteID:), deps:)` is called
- **THEN** a `ShareNoteView` is produced with a view model bound to that `noteID`

### Requirement: ShareNote route registration extension

`ShareNote` SHALL provide a `registerShareNoteRoutes(deps:)` extension on `RouteRegistry` that registers `ShareNoteRoute` with `ShareNoteNavigation.view(for:deps:)`.

#### Scenario: Registry resolves share route

- **WHEN** `registerShareNoteRoutes(deps:)` is called and `registry.view(for: ShareNoteRoute.share(noteID: id))` is invoked
- **THEN** a view for `ShareNoteView` is returned

### Requirement: ShareNote depends on ShareNoteRoutes

The `ShareNote` UI target SHALL depend on `ShareNoteRoutes` for `ShareNoteRoute` and on `Navigation` for route registry registration. It SHALL NOT require consumers to import `Navigation` for view construction.

#### Scenario: ShareNote links ShareNoteRoutes

- **WHEN** the `ShareNote` target is built
- **THEN** it imports `ShareNoteRoutes`
