## ADDED Requirements

### Requirement: App implements module dependency protocols

The app target SHALL provide concrete types conforming to `AuthFlowDependencyProviding` and `NotesDependencyProviding`. These types SHALL be internal to the app and SHALL map from `AppDependencies` without exposing `AppDependencies` to feature packages.

#### Scenario: App auth dependencies conform to protocol

- **WHEN** the app target is built
- **THEN** a type conforming to `AuthFlowDependencyProviding` is wired using `AppDependencies`

#### Scenario: Modules do not import AppDependencies type

- **WHEN** `AuthFlowUI` or `NotesFlow` package sources are inspected
- **THEN** they do not reference `AppDependencies`

### Requirement: App registers all routes at composition root

The app SHALL create a route registry, register `AuthRoute` and `NotesRoute` (and future module routes) with their `view(for:deps:)` builders, and mount `NavigationHost` with a shared `NavigationRouting` instance.

#### Scenario: Auth and notes routes registered

- **WHEN** the app launches
- **THEN** both `AuthRoute` and `NotesRoute` are registered in the route registry

### Requirement: VaultSession drives root navigation

The app SHALL observe `VaultSession.changes` and instruct the navigation router when session activity changes. When the session becomes inactive, the app SHALL reset navigation and push the auth entry route. When the session becomes active, the app SHALL reset navigation and push the main notes entry route.

#### Scenario: Inactive session shows auth entry

- **WHEN** `VaultSession` becomes inactive
- **THEN** the router pushes `AuthRoute.login` after clearing the path

#### Scenario: Active session shows notes entry

- **WHEN** `VaultSession` becomes active
- **THEN** the router pushes `NotesRoute.list` after clearing the path

### Requirement: App links Navigation package

The `superSecureNotes` app target SHALL link `Navigation`, `NavigationProtocol`, `AuthFlowRoutes`, and `NotesFlowRoutes` products.

#### Scenario: App builds with navigation products

- **WHEN** the app target is built
- **THEN** it links the Navigation and route library products

### Requirement: RootView uses NavigationHost

`RootView` SHALL use `NavigationHost` as the primary navigation container and SHALL NOT use ad-hoc parallel `NavigationStack` wrappers for auth and notes zones.

#### Scenario: Single navigation host at root

- **WHEN** `RootView` is rendered
- **THEN** a single `NavigationHost` manages the navigation stack
