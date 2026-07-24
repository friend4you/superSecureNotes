## Context

The app currently gates content with `VaultSession.changes` in `RootView`, using ad-hoc `NavigationStack` and in-package `NavigationLink` inside `AuthFlowUI`. There is no shared route model, no registry, and no way for one module to navigate to another module's screen without importing its UI.

OpenSpec prior changes established:
- `VaultSession` signals auth activity; app observes `changes` for root transitions
- `AuthFlowUI` previously owned login ↔ register navigation internally — this change moves auth screens into the app-level routing system so any screen is reachable from outside
- `NotesFlow` is UI scaffolding only; it will gain routes and a dependency protocol

The project follows a protocol/implementation split per package (`VaultSessionProtocol` / `VaultSession`, `AuthRepositoryProtocol` / `AuthRepository`). Navigation should follow the same pattern.

## Goals / Non-Goals

**Goals:**

- New `Packages/Navigation/` with `NavigationProtocol` (UI-free) and `Navigation` (SwiftUI router + host)
- `Route` protocol: `Hashable`, `Sendable` — marker for all navigable destinations
- Per-module `*Routes` targets exporting route enums only (minimal dependency for cross-module navigation)
- Per-module `*DependencyProviding` protocols — public protocol only; concrete app implementations stay in app target
- `view(for:deps:)` static builders per module, registered in app at startup
- `NavigationRouting`: `setRoot`, `push`, `present` (sheet + fullScreenCover), `pop`, `popToRoot`
- `Navigating`: shared feature-facing protocol (`NavigationRouting` + `dismissPresentation`); implemented by `AppNavigator`
- `NavigationRouter` stores root separately; push path holds pushed module routes (`path.append(route)`); **internal** to Navigation package — app uses `navigator` only
- Module deps bags hold `navigator: Navigating` (init parameter); view models navigate via deps
- Route registration validation: navigate-time in `AppNavigator` + startup `verifyRegistered(...)` + render-time safety net
- Cross-module navigation is free-for-all: any feature imports target `*Routes` and calls `push` / `present` / `setRoot`
- App handles `VaultSession` and instructs navigator on session changes (root zone transitions)
- Strict TDD per `development-practices`

**Non-Goals:**

- Deep linking / URL parsing (future module; `Route: Hashable` enables it later)
- Tab bar navigation (future)
- Auth unlock, biometrics, Keychain (auth module)
- Note data persistence or crypto (notes module)
- `AppRoute` aggregator enum (deferred; module routes pushed directly into `NavigationPath`)
- Route namespace statics (e.g. `Settings.general`); keep `AuthRoute` / `NotesRoute` naming for now
- Settings module (pattern proof only; no new feature screens in this change)

## Decisions

### 1. Navigation SPM package layout

```
Packages/Navigation/
├── Package.swift
├── Sources/
│   ├── NavigationProtocol/
│   │   ├── Route.swift
│   │   ├── NavigationRouting.swift
│   │   ├── Navigating.swift
│   │   └── RoutePresentation.swift
│   └── Navigation/
│       ├── Navigation.swift              # re-export
│       ├── RouteRegistry.swift
│       ├── NavigationRouter.swift        # internal
│       ├── AppNavigator.swift
│       ├── NavigationCoordinator.swift
│       └── SwiftUI/
│           └── NavigationHost.swift
└── Tests/
    ├── NavigationProtocolTests/
    └── NavigationTests/
```

**Rationale:** Matches existing `*Protocol` + impl split. `NavigationProtocol` has no SwiftUI dependency so `*Routes` targets can depend on it lightly.

**Alternatives considered:**
- App-only navigation — rejected; harder to test and inconsistent with package architecture
- Single target — rejected; routes libraries would pull SwiftUI

### 2. `Route` protocol (not `AppRoute`)

```swift
public protocol Route: Hashable, Sendable {}
```

Each module defines its own enum: `AuthRoute`, `NotesRoute`, etc.

**Rationale:** User naming preference. `AppRoute` reserved for optional future aggregator; not required for v1.

### 3. Module routes in separate `*Routes` targets

```
AuthFlowRoutes    → AuthRoute
NotesFlowRoutes   → NotesRoute
```

Other modules import `NotesFlowRoutes` to push `NotesRoute.detail(id)` without linking `NotesFlow` UI.

**Rationale:** Minimal cross-module dependency surface. Routes are pure data.

### 4. Protocol-only module dependencies

```swift
@MainActor
public protocol AuthFlowDependencyProviding: AnyObject {
    func makeLoginViewModel() -> DefaultLoginViewModel
    func makeRegisterViewModel() -> DefaultRegisterViewModel
}
```

App provides `AppAuthDependencies: AuthFlowDependencyProviding` in app target. Modules never see `AppDependencies`.

**Rationale:** Encapsulation; each module declares only what its screens need. Aligns with `AccessTokenProviding` / `LoginViewModel` patterns.

**Alternatives considered:**
- Struct deps — simpler but less mock-friendly; rejected for consistency with ViewModel protocols
- Pass `AppDependencies` — rejected; couples modules to full app graph

### 5. `view(for:deps:)` builder naming

Per-module internal navigation type:

```swift
enum AuthNavigation {
    @ViewBuilder
    static func view(for route: AuthRoute, deps: any AuthFlowDependencyProviding) -> some View
}
```

**Rationale:** Returns a view (factory), distinct from router actions (`push`, `present`). Avoids confusion with SwiftUI `navigationDestination` and imperative `show`/`display`.

### 6. Presentation on router API (Option A)

```swift
func setRoot<R: Route>(_ route: R)  // set root route; clear push path; dismiss modals
func push<R: Route>(_ route: R)
func present<R: Route>(_ route: R, style: RoutePresentation)  // .sheet | .fullScreenCover
func pop()
func popToRoot()
```

Routes remain pure data; presentation is a navigation concern.

**Rationale:** Keeps route enums simple. Call site explicitly chooses presentation.

### 7. Root route and `NavigationPath` for pushes

`NavigationRouter` stores the root route separately from a SwiftUI `NavigationPath` used for pushed routes. `setRoot` sets the root and clears the push path. `push` appends the concrete route directly:

```swift
func push<R: Route>(_ route: R) {
    path.append(route)
}
```

`NavigationPath` natively stores different `Hashable` route types (`AuthRoute`, `NotesRoute`, etc.) without a custom type-erasure wrapper.

`NavigationHost` renders the root from the router and binds `NavigationStack(path:)` to the push path only. It applies `.navigationDestination(for:)` per registered route type. The route registry maps each `Route.Type` to its `view(for:deps:)` builder.

**Rationale:** Matches SwiftUI's `NavigationStack` model (root content + push path). Avoids mirroring route state because `NavigationPath` is opaque and cannot expose the root entry.

**Alternatives considered:**
- `RouteBox` wrapper — rejected; redundant with `NavigationPath` type erasure
- Root stored inside `NavigationPath` — rejected; requires opaque path mirroring (`StoredRoute`)
- Single `AppRoute` aggregator enum — deferred; module routes pushed directly

### 8. Route registry at app composition

```swift
registry.register(AuthRoute.self) { route in
    AnyView(AuthNavigation.view(for: route, deps: authDeps))
}
registry.register(NotesRoute.self) { route in
    AnyView(NotesNavigation.view(for: route, deps: notesDeps))
}
```

Deps captured at registration (protocol-typed). Registry keyed by `ObjectIdentifier(Route.Type)`. `NavigationHost` wires one `navigationDestination(for:)` modifier per registered route type.

**Rationale:** Registration stays centralized; destinations stay type-safe per module route enum.

### 9. Session-driven root (app owns when, navigation owns how)

```
VaultSession.changes
       │
       ▼
  App (RootView)
       │
  false → router.setRoot(AuthRoute.login)
  true  → router.setRoot(NotesRoute.list)
```

Navigation module does not observe `VaultSession` directly.

**Rationale:** Session is app infrastructure; navigation stays presentation-focused.

### 10. AuthFlow internal navigation removal (**BREAKING**)

Remove `NavigationLink` from `LoginView`. Login view model uses `Navigating` from the deps bag to `push(AuthRoute.register)`.

`LoginView` no longer takes `makeRegisterViewModel` closure for navigation purposes — register route built via `AuthNavigation.view(for: .register, deps:)`.

**Rationale:** All auth screens reachable from outside via `AuthRoute`. Consistent with modular navigation goal.

### 11. Shared `Navigating` protocol (replaces per-module navigators)

`NavigationProtocol` defines a `@MainActor` protocol `Navigating` that inherits `NavigationRouting` and adds `dismissPresentation()`.

```swift
@MainActor
public protocol Navigating: NavigationRouting {
    func dismissPresentation()
}
```

`AppNavigator` in the `Navigation` package implements `Navigating`, wrapping an internal `NavigationRouter` and `RouteRegistry`.

Feature modules depend on `NavigationProtocol` (UI-free) and receive `any Navigating` via their deps bag — not via SwiftUI environment and not via module-specific protocols (e.g. delete `LoginNavigating` / `AuthLoginNavigator`).

**Rationale:** One navigation contract for all modules; supports free-for-all cross-module navigation without proliferating `*Navigating` adapters.

**Alternatives considered:**
- Per-module navigators (`LoginNavigating`) — rejected; does not scale to cross-module destinations
- Environment-injected router — rejected; bypasses validation, harder to test in view models

### 12. `Navigating` on module deps bags

Each module deps implementation holds `navigator: any Navigating`, passed as an **init parameter** (immutable):

```swift
authDeps = AuthFlowDependencies(..., navigator: coordinator.navigator)
notesDeps = NotesFlowDependencies(navigator: coordinator.navigator)
```

View models obtain the navigator from deps at creation time:

```swift
func makeLoginViewModel() -> DefaultLoginViewModel {
    DefaultLoginViewModel(..., navigator: navigator)
}
```

`AuthFlowDependencyProviding.makeLoginViewModel()` no longer takes a navigator parameter. `AuthNavigation.view(for:deps:)` no longer takes a navigator parameter. `registerAuthRoutes(deps:)` no longer takes a navigator parameter.

Add `navigator` to all module deps bags upfront (including modules that do not navigate yet) for uniform app wiring and to support free-for-all cross-module navigation without future deps refactors.

**Rationale:** Composition root creates coordinator first, then deps with navigator, then registers routes. Keeps navigation out of SwiftUI environment and out of registration closures.

### 13. `NavigationCoordinator` public surface

`NavigationCoordinator` exposes:
- `navigator: Navigating` — app and feature code use this
- `registry: RouteRegistry` — route registration at startup
- `hostModel: NavigationHostModel` — `NavigationHost` binding

`NavigationRouter` is **internal** to the Navigation package. App code (including `SessionRootNavigation`) calls `navigator.setRoot(...)` — never `router` directly.

**Rationale:** Single validated navigation path; prevents bypassing `AppNavigator` registration checks.

### 14. Route registration validation (layered)

Three validation layers:

| Layer | When | Purpose |
|-------|------|---------|
| Startup | After all `register*Routes()` | `registry.verifyRegistered(AuthRoute.self, NotesRoute.self, ...)` — catches missing registration at launch (debug) |
| Navigate-time | `AppNavigator.push` / `present` / `setRoot` | Assert route type is registered before mutating router state (primary; debug assert, release log + no-op) |
| Render-time | `RouteRegistry.view(forAny:)` | Safety net if router accessed directly (existing behavior) |

Registry auto-tracks registered types on `register()`. App passes expected types to `verifyRegistered(...)`. No separate per-module manifest type — registration is the source of truth; startup verifies the expected set.

**Rationale:** Fail closest to the bug. Navigate-time prevents ghost entries in `NavigationPath`. Startup catches composition mistakes before user interaction.

### 15. Remove environment-injected router

Remove `@Environment(\.navigationRouter)` from `NavigationHost` and delete `NavigationRouterEnvironment.swift`.

All navigation goes through `Navigating` injected into deps / view models. No environment escape hatch.

**Rationale:** Consistent with deps-based injection; prevents bypassing `AppNavigator` validation.

### 16. Cross-module navigation policy

Any feature module may navigate to any registered route by importing the target module's `*Routes` target:

```swift
import SettingsFlowRoutes  // lightweight; no UI

navigator.push(SettingsRoute.general)
```

No navigation boundaries between modules. Presentation is always explicit at the call site (`push` vs `present(..., style:)`).

**Rationale:** Matches modular monolith goals; `*Routes` targets keep cross-module deps minimal.

### 17. Route naming (unchanged for now)

Keep existing per-module enum names (`AuthRoute`, `NotesRoute`). Namespace statics (e.g. `Settings.general`) deferred to a later change.

## Risks / Trade-offs

- **[Risk] Unregistered route type at runtime** → Mitigation: navigate-time validation in `AppNavigator`, startup `verifyRegistered`, render-time assertion; unit tests per registered route
- **[Risk] Breaking AuthFlowUI public API** → Mitigation: update app wiring, previews, and tests in same change; remove `LoginNavigating`; document in proposal
- **[Risk] Feature protocol packages depend on NavigationProtocol** → Mitigation: `NavigationProtocol` is UI-free and lightweight; acceptable trade-off vs per-module navigator protocols
- **[Risk] Modal + push state complexity** → Mitigation: v1 keeps single presented route; document limitation
- **[Trade-off] No `AppRoute` aggregator** → Deep links need multi-module URL mapping later; acceptable per scope
- **[Trade-off] `AnyObject` on dependency protocols** → Slight reference-semantics requirement; enables stable registration captures

## Migration Plan

1. Land `Navigation` package with tests (no app changes yet)
2. Add `AuthFlowRoutes`, `NotesFlowRoutes` targets
3. Refactor `AuthFlowUI` to route-based navigation; update AuthFlow tests
4. Add `NotesDependencyProviding` / `NotesNavigation`
5. Wire app: dependency protocol impls, registry, `NavigationHost`, `VaultSession` observer
6. Remove dead `NavigationStack` / `NavigationLink` wiring from `RootView`
7. Add `Navigating`, `AppNavigator`, `verifyRegistered`; refactor auth to deps-based navigation; remove environment router and `LoginNavigating`

No data migration. Rollback: revert package and restore prior `RootView` + `LoginView` API.

## Open Questions

- None blocking v1. Deep linking module will define URL → `Route` mapping later.
- Route namespace statics (`Settings.general`) deferred to a later change.
