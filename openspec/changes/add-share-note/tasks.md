## 1. ShareNote package scaffold

- [ ] 1.1 Create `Packages/ShareNote/` with `ShareNoteRoutes` and `ShareNote` targets, test targets, and `Package.swift` (iOS 17+, macOS 14+); depend on `Navigation` package
- [ ] 1.2 Add `ShareNote` and `ShareNoteRoutes` products to `superSecureNotes.xcodeproj`

## 2. ShareNoteRoutes target

- [ ] 2.1 Write failing tests: `ShareNoteRoute` conforms to `Route`; includes `.share(noteID:)` with `UUID`; is `Hashable` and `Sendable` (`ShareNoteRoutesTests`)
- [ ] 2.2 Implement `ShareNoteRoute.share(noteID: UUID)` in `ShareNoteRoutes` target depending on `NavigationProtocol`

## 3. ShareNoteViewModel

- [ ] 3.1 Write failing tests: `DefaultShareNoteViewModel` exposes `noteID`; `dismiss()` calls `navigator.pop()` (`ShareNoteTests`)
- [ ] 3.2 Implement `ShareNoteViewModel` protocol and `DefaultShareNoteViewModel` with `Navigating` dependency

## 4. ShareNoteDependencyProviding and ShareNoteDependencies

- [ ] 4.1 Write failing tests: `ShareNoteDependencies` conforms to `ShareNoteDependencyProviding`; `makeShareNoteViewModel(noteID:)` returns `DefaultShareNoteViewModel` with matching `noteID` (`ShareNoteTests`)
- [ ] 4.2 Implement `ShareNoteDependencyProviding` protocol and `ShareNoteDependencies` concrete bag

## 5. ShareNoteView

- [ ] 5.1 Write failing tests: `ShareNoteView` renders placeholder text `"Share note"` (`ShareNoteTests`)
- [ ] 5.2 Implement `ShareNoteView` accepting `DefaultShareNoteViewModel`; add `#Preview`

## 6. ShareNoteNavigation and route registration

- [ ] 6.1 Write failing tests: `ShareNoteNavigation.view(for: .share(noteID:), deps:)` returns `ShareNoteView`; `registerShareNoteRoutes(deps:)` resolves registered route to a view (`ShareNoteTests`)
- [ ] 6.2 Implement `ShareNoteNavigation.view(for:deps:)` mapping `.share(noteID:)` to `ShareNoteView`
- [ ] 6.3 Implement `RouteRegistry.registerShareNoteRoutes(deps:)` extension in `ShareNote` target

## 7. App composition wiring

- [ ] 7.1 Write failing tests: `AppComposition` exposes `shareNoteDependencies`; `ShareNoteRoute` is registered; `verifyRegistered` includes `ShareNoteRoute.self`; active session root remains `NotesRoute.list` (`AppCompositionTests`, `SessionRootNavigationTests`)
- [ ] 7.2 Add `shareNoteDependencies: ShareNoteDependencies` to `AppComposition` wired with shared `Navigating` instance
- [ ] 7.3 Call `registerShareNoteRoutes(deps:)` and add `ShareNoteRoute.self` to `verifyRegistered` in `AppComposition`
- [ ] 7.4 Link `ShareNote` and `ShareNoteRoutes` products in app target

## 8. Final verification

- [ ] 8.1 Run full test suite; fix regressions
- [ ] 8.2 Manual smoke: app launches with share route registered; vault-active root still shows notes list
