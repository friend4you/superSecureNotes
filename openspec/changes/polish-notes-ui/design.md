## Context

Notes UI is implemented in `NotesFlow` with inline list rows (no separate cell component), `Form`-based detail screens, and `NoteSyncStatusLabel` showing icon + text. Settings is reached via `navigator.push(AuthRoute.settings)` and renders `BiometricSettingsView` (biometrics toggle only). Logout lives on `DefaultNoteListViewModel` and is exposed in `NoteListView` behind `#if DEBUG`. Share already uses `navigator.present(..., style: .sheet)` with an internal `NavigationStack` and Cancel button (`ShareNoteView` pattern).

Shared notes have no `syncState` in `SharedNoteSummary` / `SharedNote` — sync indicators apply to owned notes only.

## Goals / Non-Goals

**Goals:**

- Calmer list rows: title left, sync icon right (owned notes only)
- Detail and create screens: note title is the screen title (editable where applicable)
- Detail toolbar: Save + sync icon + `⋯` menu (Share, Delete)
- Shared detail: read-only title in nav bar, subtle owner metadata, Delete in `⋯` menu
- Settings: sheet presentation with Done dismiss; gear icon on list leading toolbar; `+` on trailing
- Logout: production row on settings screen using existing `performLogout` / `LogoutReset` flow
- Keep list long-press context menus unchanged
- Strict TDD per `development-practices`

**Non-Goals:**

- Sync state on shared notes (list or detail)
- Swipe actions on list rows
- Changes to share encryption, repository APIs, or attachment behavior
- Renaming `BiometricSettingsView` to a broader settings container (optional follow-up)
- Removing `logout()` from `NoteListViewModel` protocol if other callers exist — may deprecate list exposure only

## Decisions

### 1. Editable navigation title via `.principal`

Owned note detail and create screens bind `viewModel.title` to a `TextField` in `ToolbarItem(placement: .principal)` with `.navigationBarTitleDisplayMode(.inline)`. This removes the title `Section` from the form and tightens title-to-body spacing.

**Alternatives considered:**
- Large navigation title with separate field — rejected; wastes vertical space
- Title as first line of `TextEditor` — rejected; breaks metadata/body separation

Shared detail uses read-only `Text(viewModel.title)` in `.principal` (or `.navigationTitle(viewModel.title)`).

### 2. Icon-only sync via `NoteSyncStatusLabel` style parameter

Add a display style (e.g. `showsText: Bool` or `NoteSyncStatusDisplayStyle.iconOnly`) rather than a separate view type. List rows and detail toolbar use icon-only; accessibility labels retain full pending/synced text.

Pending: orange `arrow.triangle.2.circlepath`. Synced: secondary `checkmark.icloud`. Both always visible on owned-note surfaces.

### 3. Overflow menu pattern

First `Menu` in the app. Detail and shared detail use `Image(systemName: "ellipsis.circle")` in the trailing toolbar. Delete retains confirmation alerts. Share stays in the owned-note menu only.

List context menus are unchanged per product decision.

### 4. Settings sheet presentation

`DefaultNoteListViewModel.openSettings()` changes from `push` to `present(AuthRoute.settings, style: .sheet)`.

`BiometricSettingsView` (or a thin wrapper in `AuthNavigation.settingsView`) wraps content in `NavigationStack` and adds `ToolbarItem(placement: .cancellationAction)` Done → `navigator.dismissPresentation()`, matching `ShareNoteView`.

### 5. Logout on settings view model

Inject `performLogout: () async -> Void` and `Navigating` into `DefaultBiometricSettingsViewModel` (or a dedicated settings VM if preferred). Settings form adds a destructive logout `Button` in its own section. Remove list-toolbar logout and `#if DEBUG` guard.

`performLogout` is already composed in `AppComposition` and passed to notes list VM — extend `AuthFlowDependencies.makeBiometricSettingsViewModel()` to receive the same closure.

### 6. Shared note delete from detail

Add `delete()` to `DefaultSharedNoteDetailViewModel`: call `noteRepository.deleteSharedNote(noteID:)`, then `navigator.pop()`. Mirror owned-note delete confirmation UX in the view.

### 7. List toolbar placement (Option B)

```
[⚙️ settings — leading]     Notes     [+ create — trailing primary]
```

Separate `ToolbarItem` placements; no grouped menu.

### 8. Subtle shared-by metadata

Replace the "Shared by" `Section` header + body with a single caption line above the body, e.g. localized `"shared by \(email)"` using `.font(.caption)` and `.foregroundStyle(.tertiary)`, not in its own form section.

## Risks / Trade-offs

- **[Risk] Narrow `.principal` TextField on small devices** → Use `.lineLimit(1)`, reasonable minimum scale factor; placeholder "Untitled" when empty
- **[Risk] Settings sheet lacks nav stack today** → Wrap in `NavigationStack` inside presented content (proven by ShareNote)
- **[Risk] Source-contains tests break on layout refactor** → Update `NoteDetailViewTests`, `NoteListViewTests`, `DefaultNoteListViewModelTests` alongside implementation
- **[Trade-off] Sync icon always visible when synced** → Slightly noisier list; accepted per product decision for at-a-glance cloud state

## Migration Plan

Single app release; no data migration. Users gain settings sheet and production logout; DEBUG builds lose redundant list logout button.

## Open Questions

None — all product decisions resolved in exploration.
