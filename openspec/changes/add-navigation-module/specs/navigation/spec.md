## ADDED Requirements

### Requirement: Navigation package module boundary

The project SHALL provide a Swift Package `Navigation` with two library products: `NavigationProtocol` and `Navigation`. `NavigationProtocol` SHALL support iOS 17+ and macOS 13+ and SHALL NOT depend on SwiftUI. `Navigation` SHALL depend on `NavigationProtocol` and SwiftUI.

#### Scenario: Package builds with both targets

- **WHEN** the `Navigation` package is built
- **THEN** `NavigationProtocol` and `Navigation` targets compile successfully on supported platforms

#### Scenario: NavigationProtocol has no SwiftUI dependency

- **WHEN** `NavigationProtocol` is built
- **THEN** it does not import SwiftUI

### Requirement: Route protocol

`NavigationProtocol` SHALL define a public protocol `Route` that inherits `Hashable` and `Sendable`. Module route enums SHALL conform to `Route`.

#### Scenario: Route enum conforms to Route

- **WHEN** a module defines `enum NotesRoute: Route { case list }`
- **THEN** `NotesRoute` can be used with navigation APIs constrained to `Route`

### Requirement: NavigationRouting protocol

`NavigationProtocol` SHALL define a `@MainActor` protocol `NavigationRouting` with methods to `push` a route, `present` a route with a presentation style, `pop`, and `popToRoot`. `present` SHALL support sheet and full-screen cover styles via a `RoutePresentation` type.

#### Scenario: Push appends to navigation path

- **WHEN** `router.push(NotesRoute.list)` is called
- **THEN** the router's navigation path grows by one entry

#### Scenario: Present sets modal route

- **WHEN** `router.present(NotesRoute.list, style: .sheet)` is called
- **THEN** the router exposes a presented route for sheet display

#### Scenario: PopToRoot clears path

- **WHEN** `router.popToRoot()` is called
- **THEN** the navigation path is empty

### Requirement: RouteBox type erasure

`Navigation` SHALL provide a public `RouteBox` type that is `Hashable` and `Sendable`, constructible from any `Route`, and able to recover the original route value by type.

#### Scenario: RouteBox round-trips route

- **WHEN** `RouteBox(NotesRoute.list)` is created and unwrapped as `NotesRoute`
- **THEN** the unwrapped value equals `NotesRoute.list`

### Requirement: Route registry

`Navigation` SHALL provide a route registry that maps a concrete route type to a view builder. Registration SHALL occur at app composition time. The registry SHALL resolve a `RouteBox` to a SwiftUI view.

#### Scenario: Registered route resolves to view

- **WHEN** `NotesRoute` is registered with a view builder and the registry resolves `RouteBox(NotesRoute.list)`
- **THEN** a non-empty SwiftUI view is returned

#### Scenario: Unregistered route fails in debug

- **WHEN** the registry resolves a `RouteBox` for a route type that was not registered
- **THEN** debug builds surface a diagnosable failure

### Requirement: NavigationHost

`Navigation` SHALL provide a `NavigationHost` SwiftUI view that binds to a `NavigationRouting` implementation, renders the navigation stack from the router path, applies registered destinations, and supports presented routes (sheet and full-screen cover).

#### Scenario: NavigationHost renders pushed route

- **WHEN** `NavigationHost` is mounted and the router pushes a registered route
- **THEN** the corresponding screen appears in the navigation hierarchy

### Requirement: Navigation does not observe VaultSession

The `Navigation` package SHALL NOT depend on `VaultSession` or observe session state. Session-driven navigation SHALL be performed by the app calling router methods.

#### Scenario: No VaultSession import in Navigation

- **WHEN** `Navigation` package sources are inspected
- **THEN** they do not import `VaultSession` or `VaultSessionProtocol`
