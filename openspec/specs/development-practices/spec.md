## Requirements

### Requirement: Strict test-driven development

The project SHALL follow strict test-driven development (TDD) for all new behavior across every module and change. Implementation tasks MUST be preceded by failing tests that express the intended behavior. Developers SHALL follow the red → green → refactor cycle: write a failing test, implement the minimum code to pass, then refactor while keeping tests green.

#### Scenario: New behavior starts with a failing test

- **WHEN** a task adds or changes observable behavior
- **THEN** a failing test that describes that behavior exists before production code is written

#### Scenario: Tests pass before task completion

- **WHEN** an implementation task is marked complete
- **THEN** all related tests pass and no previously passing tests regress

#### Scenario: OpenSpec scenarios drive test cases

- **WHEN** a capability spec defines a scenario (WHEN/THEN)
- **THEN** at least one automated test covers that scenario before the feature is implemented

### Requirement: Test-first task ordering

Work breakdowns (e.g. `tasks.md` in a change) SHALL order test tasks immediately before their corresponding implementation tasks. A dedicated "tests at the end" section SHALL NOT be used for new work.

#### Scenario: Implementation follows its test task

- **WHEN** a change task list includes an implementation item
- **THEN** the preceding task in the same section writes the failing tests for that behavior

### Requirement: Test layers by module type

| Layer | Framework | TDD approach |
|-------|-----------|--------------|
| Swift Packages (e.g. `SecureCrypto`) | XCTest in package test target | Strict unit TDD on public APIs |
| App domain / use cases / ViewModels | XCTest in app unit test target | Strict unit TDD on behavior |
| SwiftUI views | XCTest (via ViewModel) or snapshot tests | TDD on ViewModel; view rendering tested after |
| End-to-end flows | XCUITest | Written when flow exists; not blocking unit TDD |

#### Scenario: Crypto primitive developed test-first

- **WHEN** a new cryptographic primitive or serializer is added to `SecureCrypto`
- **THEN** package unit tests are written first, including known vectors and roundtrip cases where applicable

#### Scenario: UI behavior tested at the ViewModel seam

- **WHEN** a SwiftUI screen introduces new user-visible behavior
- **THEN** tests target the ViewModel or use case that drives the view, not the SwiftUI layout tree directly

### Requirement: No retrofit of completed work

Work completed before the TDD policy was adopted MAY remain as-is. TDD SHALL apply to all new tasks from the adoption point forward without mandatory rework of earlier steps.

#### Scenario: Pre-policy code is grandfathered

- **WHEN** a module was implemented before strict TDD was adopted
- **THEN** it is not required to be rewritten solely to satisfy this policy unless behavior changes
