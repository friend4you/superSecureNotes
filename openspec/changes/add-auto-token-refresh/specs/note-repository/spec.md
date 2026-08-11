## ADDED Requirements

### Requirement: Note API unauthorized refresh and retry

`NoteAPIClient` SHALL use `AuthorizedRequestPerformer` for all authenticated endpoints. When the server responds `401` with error code `unauthorized`, the client SHALL attempt token refresh and retry the request once before surfacing `NoteRepositoryError.notAuthenticated`.

#### Scenario: List notes retries after token refresh

- **WHEN** `GET /notes` returns `401`, refresh succeeds, and the retried request returns `200`
- **THEN** `listNotes` returns the parsed note summaries

#### Scenario: List notes maps unauthorized after failed refresh

- **WHEN** `GET /notes` returns `401` and refresh fails with `notAuthenticated`
- **THEN** `listNotes` throws `NoteRepositoryError.notAuthenticated`

#### Scenario: Write body retries after token refresh

- **WHEN** `PUT /notes/{noteId}/body` returns `401`, refresh succeeds, and the retried request succeeds
- **THEN** the write completes without surfacing `notAuthenticated`

#### Scenario: Delete note retries after token refresh

- **WHEN** `DELETE /notes/{noteId}` returns `401`, refresh succeeds, and the retried request returns `204`
- **THEN** the delete completes without surfacing `notAuthenticated`
