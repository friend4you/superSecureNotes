## ADDED Requirements

### Requirement: Session expired message on forced logout

When the app performs a forced logout because the refresh token is dead mid-session, the system SHALL display a localized user-visible message (e.g. "Your session has expired. Please sign in again.") before or while navigating to the login screen.

#### Scenario: Message shown on session expiry logout

- **WHEN** a mid-session API call fails refresh with `notAuthenticated` and forced logout runs
- **THEN** the user sees a session-expired message on the login or auth screen

#### Scenario: User-initiated logout has no session-expired message

- **WHEN** the user taps logout from settings or unlock screen
- **THEN** no session-expired message is shown

#### Scenario: Unlock password re-login has no session-expired message

- **WHEN** unlock refresh fails and password re-login succeeds
- **THEN** no session-expired message is shown and the user reaches the notes flow
