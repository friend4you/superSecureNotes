## Context

`NotesFlow` and `AuthFlow` already follow a modular navigation pattern: a thin `*Routes` library (depends only on `NavigationProtocol`) and a UI target with `*DependencyProviding`, `*Navigation.view(for:deps:)`, and a `RouteRegistry` registration extension. The app composes module deps bags and registers all routes at startup.

`add-vault-identity-keys` laid cryptographic groundwork for note sharing, but no share UI module exists yet. This change scaffolds `Packages/ShareNote/` as the home for share journeys, starting with one screen keyed by `noteID`.

## Goals / Non-Goals

**Goals:**

- New Swift Package `Packages/ShareNote/` with `ShareNote` and `ShareNoteRoutes` library products
- Public `ShareNoteRoute.share(noteID: UUID)` conforming to `Route`
- Public `ShareNoteView` showing `"Share note"` placeholder text
- `ShareNoteViewModel` protocol and `DefaultShareNoteViewModel` with `noteID` and `Navigating` dependency
- `ShareNoteDependencyProviding` + `ShareNoteDependencies` concrete bag
- `ShareNoteNavigation.view(for:deps:)` and `RouteRegistry.registerShareNoteRoutes(deps:)`
- App registers `ShareNoteRoute` and includes it in `verifyRegistered`
- Platforms: iOS 17+, macOS 14+ (match sibling packages)
- Strict TDD for all new behavior

**Non-Goals:**

- Navigation from `NotesFlow` to `ShareNoteRoute` (future change)
- `VaultSession`, `VaultRepository`, or `SecureCrypto` integration
- Recipient public-key lookup, encryption, or share payload generation
- `ShareNoteRoute` as a session root route
- Protocol/implementation target split beyond routes library (single UI target is sufficient for v1)

## Decisions

### 1. Package name: `ShareNote`

```
Packages/ShareNote/
├── Package.swift
├── Sources/
│   ├── ShareNoteRoutes/
│   │   └── ShareNoteRoute.swift
│   └── ShareNote/
│       ├── ShareNoteView.swift
│       ├── ViewModels/DefaultShareNoteViewModel.swift
│       ├── ShareNoteDependencyProviding.swift
│       ├── ShareNoteDependencies.swift
│       └── Navigation/
│           ├── ShareNoteNavigation.swift
│           └── RouteRegistry+ShareNoteRoutes.swift
└── Tests/
    ├── ShareNoteRoutesTests/
    └── ShareNoteTests/
```

**Rationale:** Short, journey-specific name. Products `ShareNote` and `ShareNoteRoutes` mirror `NotesFlow` / `NotesFlowRoutes` naming without redundant `Flow` suffix.

**Alternatives considered:**
- `ShareNoteFlow` — consistent with `NotesFlow`; rejected per product naming preference
- Extend `NotesFlow` with `NotesRoute.share` — couples share journey to notes module; rejected

### 2. Parameterized route: `ShareNoteRoute.share(noteID: UUID)`

```swift
public enum ShareNoteRoute: Route {
    case share(noteID: UUID)
}
```

**Rationale:** Share screen always operates on a specific note. `UUID` is `Hashable` and `Sendable`, satisfying `Route` constraints. Cross-module callers can push without importing `ShareNote` UI.

**Alternatives considered:**
- `case share` (no ID) — simpler scaffold but wrong shape; rejected
- Embed in `NotesRoute` — rejected (separate package decision)

### 3. ViewModel depends on `Navigating` only

```swift
@MainActor
public protocol ShareNoteViewModel: Observable {
    var noteID: UUID { get }
    func dismiss()
}
```

`DefaultShareNoteViewModel` stores `noteID` and `navigator: any Navigating`. `dismiss()` calls `navigator.pop()`.

**Rationale:** Minimal v1 seam. Navigation is the only behavior to test now. Crypto and repository deps arrive when share logic is implemented.

### 4. App registers routes only — no entry navigation yet

`AppComposition` creates `ShareNoteDependencies`, calls `registerShareNoteRoutes`, and adds `ShareNoteRoute.self` to `verifyRegistered`. `SessionRootNavigation` is unchanged (`NotesRoute.list` remains vault-active root).

**Rationale:** Establishes registry wiring without coupling `NotesFlow` to share navigation prematurely.

### 5. `ShareNote` UI target depends on `Navigation` for registry extension

`RouteRegistry+ShareNoteRoutes.swift` lives in `ShareNote` and imports `Navigation` (same pattern as `NotesFlow`).

**Rationale:** Keeps registration API colocated with the module. `ShareNoteRoutes` stays UI-free for cross-module route references.

### 6. Dependency bag naming: `ShareNoteDependencies`

Concrete `@MainActor` class `ShareNoteDependencies: ShareNoteDependencyProviding` in the `ShareNote` package, wired in `AppComposition` (not public from app).

**Rationale:** Matches `NotesFlowDependencies` convention.

## Risks / Trade-offs

- **[Placeholder has no share logic]** → Acceptable for scaffold; add crypto/repository tests when share behavior is implemented
- **[Route registered but unreachable in UI]** → Expected for v1; manual test can push via debug harness if needed
- **[noteID not validated against vault]** → Out of scope; validation belongs in share logic change
- **[dismiss uses pop only]** → Sufficient for push presentation; sheet dismissal can use `dismissPresentation()` in a later change

## Migration Plan

Greenfield addition — no migration. Steps:

1. Add `Packages/ShareNote/` and verify package builds
2. Add local package reference in Xcode; link `ShareNote` and `ShareNoteRoutes` to app target
3. Update `AppComposition` to register share routes

Rollback: remove package reference and app wiring; delete `Packages/ShareNote/`.

## Open Questions

- None for v1 scaffold scope
