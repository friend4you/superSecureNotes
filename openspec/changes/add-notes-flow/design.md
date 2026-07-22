## Context

`SecureCrypto` and `VaultSession` provide cryptographic and in-memory key infrastructure. The app target (`superSecureNotes`) is still a placeholder (`ContentView` with "Hello, world!"). No SwiftUI module exists yet for note-related screens.

Future work will add note list data, detail, and create flows. This change establishes `Packages/NotesFlow/` as the UI home for those journeys, starting with a single placeholder list screen the app can navigate to.

## Goals / Non-Goals

**Goals:**

- New Swift Package `Packages/NotesFlow/` with one `NotesFlow` library target
- Public `NoteListView` showing `"Note list"` placeholder text
- `#Preview` for `NoteListView` in the package
- Link `NotesFlow` only to the app target; present `NoteListView` from app entry/navigation
- Platforms: iOS 17+, macOS 13+ (match sibling packages)

**Non-Goals:**

- Note data models, persistence, or encryption
- `VaultSession` or `SecureCrypto` integration
- Detail view, create note flow, ViewModels, or routing beyond showing the list screen
- Protocol/implementation target split (single SwiftUI module is sufficient for v1)
- Dedicated unit tests for static placeholder UI (first TDD work arrives with ViewModels/behavior)

## Decisions

### 1. Package name: `NotesFlow`

```
Packages/NotesFlow/
├── Package.swift
└── Sources/NotesFlow/
    └── NoteListView.swift
```

**Rationale:** Describes the module's purpose (note user journeys) without implying read-only preview semantics. Room to add `NoteDetailView`, `CreateNoteView`, and navigation later.

**Alternatives considered:**
- `NotesUI` — accurate but less journey-oriented; rejected per product naming preference
- `NotePreview` — suggests read-only snippet; rejected

### 2. Single target (no protocol split)

One `NotesFlow` target exporting SwiftUI views.

**Rationale:** No abstraction or mockable contracts needed for a static placeholder. Matches YAGNI; protocol split can be added if ViewModels need test seams later.

### 3. Public view: `NoteListView`

```swift
import SwiftUI

public struct NoteListView: View {
    public init() {}

    public var body: some View {
        Text("Note list")
    }
}

#Preview {
    NoteListView()
}
```

**Rationale:** Clear, discoverable entry point for the note list journey. Public `init()` allows app and previews to construct without package-internal coupling.

### 4. App-only dependency

Only `superSecureNotes` links `NotesFlow`. Feature/crypto packages do not import UI.

**Rationale:** Keeps dependency direction clean: app composes UI + domain; domain packages stay UI-free.

### 5. App integration via `ContentView`

Replace or wrap the placeholder `ContentView` body to show `NoteListView()` (optionally inside `NavigationStack` for future pushes).

**Rationale:** Minimal change to existing app shell; navigation chrome can grow in place.

## Risks / Trade-offs

- **[Placeholder has no testable behavior]** → Acceptable for scaffold; add ViewModel tests when list loads real data
- **[Package may grow large]** → Split targets later (e.g. `NotesFlow` + `NotesFlowCore`) if ViewModels accumulate; not needed now
- **[No session gating yet]** → List is always visible; auth gating belongs in app router when auth module exists

## Migration Plan

Greenfield addition — no migration. Steps:

1. Add `Packages/NotesFlow/` and verify package builds
2. Add local package reference in Xcode; link to app target only
3. Update `ContentView` (or app root) to show `NoteListView`

Rollback: remove package reference and app import; delete `Packages/NotesFlow/`.

## Open Questions

- None for v1 placeholder scope
