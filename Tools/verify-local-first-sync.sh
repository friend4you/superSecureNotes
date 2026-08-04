#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://localhost:8000/v1}"
IOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_ID="$(date +%s)"
EMAIL="manual-verify-${RUN_ID}@example.com"
PASSWORD="verify-password-${RUN_ID}"
NOTE_ID="550e8400-e29b-41d4-a716-446655440099"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

pass() { printf '✓ %s\n' "$1"; }
fail() { printf '✗ %s\n' "$1" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$1"; }

json_field() {
  python3 -c "import json,sys; print(json.load(sys.stdin)$1)"
}

write_fixture_files() {
  python3 - "$TMP_DIR/vault.header" "$TMP_DIR/note.blob" "$NOTE_ID" <<'PY'
import struct, sys, uuid
vault_path, note_path, note_id_str = sys.argv[1:4]
note_id = uuid.UUID(note_id_str)

def u32(v):
    return struct.pack(">I", v)

def u64(v):
    return struct.pack(">Q", v)

def lp(data):
    return u32(len(data)) + data

def lps(value):
    return lp(value.encode("utf-8"))

vault = bytearray(b"SSNV")
vault.append(2)
vault.append(1)
vault.extend(bytes([0xAA] * 32))
vault.extend(u32(600_000))
vault.extend(lp(bytes([0x01] * 60)))
vault.extend(lp(bytes([0x02] * 60)))
vault.append(1)
vault.extend(bytes([0x11] * 32))
vault.extend(lp(bytes([0x22] * 60)))

note = bytearray(b"SSNT")
note.append(1)
note.extend(note_id.bytes)
note.extend(lps("Manual verification note"))
note.extend(u64(1_700_000_000))
note.extend(u64(1_700_000_100))
note.extend(u32(0))
note.extend(u64(0))
note.extend(lp(bytes([0xAB] * 60)))
note.extend(lp(bytes([0xCD] * 32)))

open(vault_path, "wb").write(bytes(vault))
open(note_path, "wb").write(bytes(note))
PY
}

section "API health"
health="$(curl -fsS "${API_BASE%/v1}/health")"
[[ "$health" == *"ok"* ]] || fail "API health check failed: ${health}"
pass "API is reachable"

section "API auth + vault + notes + delete (9.2 / 9.3 server contract)"
register_response="$(curl -fsS -X POST "${API_BASE}/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")"
access_token="$(printf '%s' "$register_response" | json_field "['accessToken']")"
[[ -n "$access_token" ]] || fail "Register did not return accessToken"
pass "Registered test user ${EMAIL}"

auth_header="Authorization: Bearer ${access_token}"
write_fixture_files

vault_status="$(curl -s -o /dev/null -w '%{http_code}' -X PUT "${API_BASE}/vault/header" \
  -H "$auth_header" \
  -H 'Content-Type: application/octet-stream' \
  --data-binary @"${TMP_DIR}/vault.header")"
[[ "$vault_status" == "204" ]] || fail "PUT /vault/header failed with HTTP ${vault_status}"
pass "Uploaded vault header"

put_response="$(curl -fsS -X PUT "${API_BASE}/notes/${NOTE_ID}" \
  -H "$auth_header" \
  -H 'Content-Type: application/octet-stream' \
  --data-binary @"${TMP_DIR}/note.blob")"
sync_state="$(printf '%s' "$put_response" | json_field "['syncState']")"
[[ "$sync_state" == "synced" ]] || fail "PUT /notes did not return syncState=synced"
pass "Uploaded note ${NOTE_ID} with syncState=synced"

listed="$(curl -fsS -H "$auth_header" "${API_BASE}/notes")"
[[ "$listed" == *"${NOTE_ID}"* ]] || fail "GET /notes did not include uploaded note"
pass "Note appears in remote catalog (pull source for 9.3)"

delete_status="$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "${API_BASE}/notes/${NOTE_ID}" \
  -H "$auth_header")"
[[ "$delete_status" == "204" ]] || fail "DELETE /notes failed with HTTP ${delete_status}"
pass "Remote DELETE succeeded (9.2 server side)"

missing_status="$(curl -s -o /dev/null -w '%{http_code}' -H "$auth_header" "${API_BASE}/notes/${NOTE_ID}")"
[[ "$missing_status" == "404" ]] || fail "Deleted note still downloadable (HTTP ${missing_status})"
pass "Deleted note returns 404 on GET"

section "iOS automated tests"
(
  cd "$IOS_ROOT/Packages/NoteRepository"
  swift test -q
)
pass "NoteRepository package tests"

(
  cd "$IOS_ROOT/Packages/NotesFlow"
  swift test -q
)
pass "NotesFlow package tests"

section "iOS app build"
xcodebuild build \
  -project "${IOS_ROOT}/superSecureNotes.xcodeproj" \
  -scheme superSecureNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -quiet
pass "superSecureNotes builds for iOS Simulator"

section "Manual simulator checklist (9.1–9.3)"
cat <<'EOF'
Prerequisites:
  - API running at http://localhost:8000 (docker compose up in super-secure-notes-api)
  - Run superSecureNotes on iOS Simulator (Debug)

9.1 Register → create note → sync indicators → persistence
  1. Register a new account; complete vault setup.
  2. Create a note.
  3. List row shows "Pending sync" (orange), then "Synced" after refresh/unlock flush.
  4. Force-quit app → unlock → note still present locally.

9.2 Delete → immediate removal → remote DELETE after flush
  1. Delete a note; it disappears from the list immediately.
  2. Pull to refresh.
  3. Confirm GET /v1/notes/{noteId} returns 404.

9.3 Cleared local data → login → vault + notes pulled
  1. Delete app from Simulator; reinstall from Xcode.
  2. Login with an account that has server-side notes + vault header.
  3. Unlock vault; notes appear after sync/pull.
  4. Disable network; open a note offline to confirm local persistence.
EOF

pass "Automated checks complete. Finish the simulator checklist above for full section 9 sign-off."
