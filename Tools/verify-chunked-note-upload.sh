#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://localhost:8000/v1}"
IOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STEP="${1:-all}"

pass() { printf '✓ %s\n' "$1"; }
fail() { printf '✗ %s\n' "$1" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$1"; }

require_api() {
  local health
  health="$(curl -fsS "${API_BASE%/v1}/health")"
  [[ "$health" == *"ok"* ]] || fail "API health check failed: ${health}"
  pass "API reachable at ${API_BASE%/v1}"
}

run_note_repository_tests() {
  local filter="$1"
  (
    cd "$IOS_ROOT/Packages/NoteRepository"
    swift test --filter "$filter" -q
  )
}

run_notes_flow_tests() {
  local filter="$1"
  (
    cd "$IOS_ROOT/Packages/NotesFlow"
    swift test --filter "$filter" -q
  )
}

build_app() {
  xcodebuild build \
    -project "${IOS_ROOT}/superSecureNotes.xcodeproj" \
    -scheme superSecureNotes \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -quiet
}

verify_8_1() {
  section "8.1 Automated proxies — small note sync-on-save + UI outcome path"
  require_api

  run_note_repository_tests "NoteSyncOutcomeTests"
  pass "scheduleFlush emits outcomes after push (NoteSyncOutcomeTests)"

  run_notes_flow_tests "DefaultCreateNoteViewModelTests/testSaveCallsScheduleFlushAfterSuccessfulWrite"
  pass "Create save schedules background flush"

  run_notes_flow_tests "DefaultNoteListViewModelTests/testReloadsListOnSuccessfulSyncOutcome"
  pass "List VM patches row on sync outcome (no pull-to-refresh needed)"

  run_notes_flow_tests "NotesFlowDependenciesTests/testNotesFlowDependenciesPassesNoteSyncOutcomeStreamToListViewModel"
  pass "NotesFlowDependencies wires outcome stream to list VM"

  (
    cd "$IOS_ROOT"
    xcodebuild test \
      -scheme superSecureNotes \
      -destination 'platform=iOS Simulator,name=iPhone 17' \
      -only-testing:superSecureNotesTests/AppCompositionTests/testAppCompositionPassesNoteSyncServiceToNotesDependencies \
      -quiet
  )
  pass "AppComposition injects LocalFirstNoteSyncService into NotesFlow"

  build_app
  pass "superSecureNotes builds for iOS Simulator"

  section "8.1 Manual simulator checklist"
  cat <<'EOF'
Prerequisites:
  - API at http://localhost:8000 (same machine as Simulator)
  - Run superSecureNotes on iOS Simulator (Debug, no -UseStubBackend if you want real sync)

Steps:
  1. Register a new account (or login) and unlock the vault.
  2. Create a small note (short title/body, no large attachments).
  3. After save, list row should show Pending sync immediately (orange indicator).
  4. Within a few seconds, the same row should flip to Synced WITHOUT pull-to-refresh.
  5. Optional: open note detail — sync indicator should also show Synced.

Sign-off: mark tasks.md 8.1 [x] when steps 3–4 pass in the simulator.
EOF
}

verify_8_2() {
  section "8.2 Automated proxies — chunked upload API + resume tests"
  require_api

  run_note_repository_tests "NoteAPIClientChunkedUploadTests"
  pass "Chunked upload API client (init → chunks → complete)"

  run_note_repository_tests "NetworkNoteRepositoryChunkedUploadTests"
  pass "Over-threshold upload uses chunked path with chunk retry"

  run_note_repository_tests "LocalFirstNoteSyncServiceChunkedUploadTests"
  pass "Session persistence, resume skips completed chunks, wire-size mismatch re-inits"

  run_note_repository_tests "NotesIndexStoreUploadSessionTests"
  pass "Upload session rows survive store reopen"

  section "8.2 Manual simulator checklist — large note + mid-upload kill"
  cat <<'EOF'
Prerequisites:
  - API at http://localhost:8000
  - Note with wire blob > 10 MB (e.g. large attachment or very large body)

Steps:
  1. Create or edit a note so the encrypted wire blob exceeds 10 MB.
  2. Save — list/detail should show Pending sync; wait for Synced (chunked path).
  3. Repeat with a slow network (Network Link Conditioner) or large payload:
     - Save note → Pending appears
     - Force-quit app while still Pending (mid-chunked-upload)
     - Relaunch → unlock → note still local; flush resumes same upload session
     - Row reaches Synced without re-uploading completed chunks from scratch

Sign-off: mark tasks.md 8.2 [x] when resume-after-kill completes to Synced.
EOF
}

verify_8_3() {
  section "8.3 Automated proxies — session invalidation on local edit"
  run_note_repository_tests "LocalFirstNoteSyncServiceChunkedUploadTests/testFlushInvalidatesSessionWhenWireSizeChanges"
  pass "Wire size mismatch deletes persisted session and re-inits upload"

  section "8.3 Manual simulator checklist — edit during pending chunked upload"
  cat <<'EOF'
Prerequisites:
  - API at http://localhost:8000
  - Large note (>10 MB wire blob) or throttled network so upload stays Pending long enough

Steps:
  1. Start a chunked upload (save large note → Pending on list and detail).
  2. Before Synced, open the note and edit title/body (or add attachment) → Save.
  3. Detail should return to Pending with new content.
  4. After flush completes, row/detail show Synced.
  5. Optional server check: GET note reflects final edited content, not pre-edit blob.

Sign-off: mark tasks.md 8.3 [x] when edited content is what syncs after Pending clears.
EOF
}

case "$STEP" in
  8.1) verify_8_1 ;;
  8.2) verify_8_2 ;;
  8.3) verify_8_3 ;;
  all)
    verify_8_1
    verify_8_2
    verify_8_3
    section "Section 8 automated proxies complete"
    pass "Finish the manual simulator checklists above for full sign-off."
    ;;
  *)
    fail "Unknown step '${STEP}'. Use: 8.1, 8.2, 8.3, or all"
    ;;
esac
