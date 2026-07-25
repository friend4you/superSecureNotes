## ADDED Requirements

### Requirement: App registers ShareNote routes at composition root

The app SHALL register `ShareNoteRoute` with its `view(for:deps:)` builder via `registerShareNoteRoutes`, include `ShareNoteRoute.self` in `verifyRegistered`, and wire `ShareNoteDependencies` with the shared `Navigating` instance.

#### Scenario: ShareNote route registered at launch

- **WHEN** the app launches
- **THEN** `ShareNoteRoute` is registered in the route registry alongside `AuthRoute` and `NotesRoute`

#### Scenario: ShareNote dependencies receive navigator

- **WHEN** the app composition root is initialized
- **THEN** `ShareNoteDependencies` receives the shared `Navigating` instance

#### Scenario: verifyRegistered includes ShareNoteRoute

- **WHEN** route registration completes in debug builds
- **THEN** `verifyRegistered` is called with `ShareNoteRoute.self` included

### Requirement: App links ShareNote package products

The `superSecureNotes` app target SHALL link `ShareNote` and `ShareNoteRoutes` products.

#### Scenario: App builds with ShareNote products

- **WHEN** the app target is built
- **THEN** it links the `ShareNote` and `ShareNoteRoutes` library products

### Requirement: ShareNote is not a session root route

`SessionRootNavigation` SHALL NOT change. When the vault session is active, the root route SHALL remain `NotesRoute.list`.

#### Scenario: Active session root unchanged

- **WHEN** `VaultSession` becomes active
- **THEN** the navigator calls `setRoot(NotesRoute.list)` and does not set `ShareNoteRoute` as root
