#!/usr/bin/env bash
# Integration tests for AGENT_MODEL_NAMES: agents in herdr's panel named after
# the model their session runs, read from the transcript, unique per herdr's
# duplicate rule, hand names respected, --clear reverting only ours.

set -o pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tests/lib.sh
. "$here/lib.sh"

ENGINE="$here/../automatic-rename.sh"
MOCK="$here/mocks/herdr"
chmod +x "$MOCK" 2>/dev/null || true

setup() {
  SB=$(mktemp -d "${TMPDIR:-/tmp}/hal-agent.XXXXXX")
  export HERDR_MOCK_DIR="$SB/fixtures"; mkdir -p "$HERDR_MOCK_DIR"
  export HERDR_MOCK_LOG="$SB/renames.log"; : >"$HERDR_MOCK_LOG"
  export HERDR_BIN_PATH="$MOCK"
  export XDG_STATE_HOME="$SB/state"
  export HERDR_AUTOMATIC_RENAME_CONFIG="$SB/config.sh"
  printf 'AGENT_MODEL_NAMES=1\n' >"$HERDR_AUTOMATIC_RENAME_CONFIG"
  export HERDR_CONFIG_FILE="$SB/herdr.toml"
  export HERDR_SOCKET_PATH="$SB/herdr.sock"
  export SHELL_NAME=zsh
  export NAME_TABS=0 AUTO_INDEX=0
  unset HERDR_TAB_ID HERDR_PANE_ID HERDR_PLUGIN_CONTEXT_JSON
  export CLAUDE_CONFIG_DIR="$SB/claude" CODEX_HOME="$SB/codex"
  STORE="$XDG_STATE_HOME/herdr-automatic-rename/agents.json"
  # transcripts: two fable sessions, one opus, one codex thread
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/-home-u" "$CODEX_HOME/sessions/2026/09/09"
  for id in aaaaaaaa-0000-4000-8000-000000000001 aaaaaaaa-0000-4000-8000-000000000002; do
    printf '{"type":"assistant","message":{"role":"assistant","model":"claude-fable-5-1","content":[]}}\n' \
      >"$CLAUDE_CONFIG_DIR/projects/-home-u/$id.jsonl"
  done
  printf '{"type":"assistant","message":{"role":"assistant","model":"claude-fable-5-1","content":[]}}\n{"type":"assistant","message":{"role":"assistant","model":"claude-opus-5","content":[]}}\n' \
    >"$CLAUDE_CONFIG_DIR/projects/-home-u/aaaaaaaa-0000-4000-8000-000000000003.jsonl"
  printf '{"type":"turn_context","payload":{"model":"gpt-6-astra"}}\n' \
    >"$CODEX_HOME/sessions/2026/09/09/rollout-2026-09-09T00-00-00-bbbbbbbb-0000-4000-8000-000000000004.jsonl"
}
fixture() { cat >"$HERDR_MOCK_DIR/$1"; }
run_event() { /usr/bin/env bash "$ENGINE" "$@"; }
log() { cat "$HERDR_MOCK_LOG"; }
teardown() { rm -rf "$SB" 2>/dev/null || true; }

# agents_fixture <nameA> <nameB> <nameC> <nameD>  ("" = unnamed)
agents_fixture() {
  local a=${1:+\"$1\"} b=${2:+\"$2\"} c=${3:+\"$3\"} d=${4:+\"$4\"}
  fixture snapshot.json <<JSON
{"result":{"snapshot":{
  "workspaces":[{"workspace_id":"w1","label":"claude"}],
  "tabs":[], "panes":[], "layouts":[],
  "agents":[
    {"pane_id":"w1:pA","agent":"claude","name":${a:-null},"cwd":"/home/u","agent_session":{"value":"aaaaaaaa-0000-4000-8000-000000000001"}},
    {"pane_id":"w1:pB","agent":"claude","name":${b:-null},"cwd":"/home/u","agent_session":{"value":"aaaaaaaa-0000-4000-8000-000000000002"}},
    {"pane_id":"w1:pC","agent":"claude","name":${c:-null},"cwd":"/home/u","agent_session":{"value":"aaaaaaaa-0000-4000-8000-000000000003"}},
    {"pane_id":"w1:pD","agent":"codex","name":${d:-null},"cwd":"/home/u","agent_session":{"value":"bbbbbbbb-0000-4000-8000-000000000004"}}
  ]
}}}
JSON
}

# ---- Scenario 1: fresh panel -> named, duplicates suffixed, last model wins ----
setup
agents_fixture "" "" "" ""
HOME=/home/u run_event pane.agent_detected
out=$(log)
check_contains "first fable"            "$out" "agent rename w1:pA fable"
check_contains "second fable is -2"     "$out" "agent rename w1:pB fable-2"
check_contains "the LAST model wins"    "$out" "agent rename w1:pC opus"
check_contains "codex from turn_context" "$out" "agent rename w1:pD gpt-6-astra"
check "store records the names" "fable-2" "$(jq -r '."w1:pB".name' "$STORE")"
# second pass with the names landed: nothing to do, suffix kept
: >"$HERDR_MOCK_LOG"
agents_fixture fable fable-2 opus gpt-6-astra
ln "$STORE" "$SB/settled-store"
HOME=/home/u run_event pane.agent_status_changed
check "a settled panel issues no rename" "" "$(log)"
check "a settled panel does not rewrite its store" "same" "$(if [ "$STORE" -ef "$SB/settled-store" ]; then echo same; else echo replaced; fi)"
# pA closes; pB keeps its -2 rather than being renumbered
: >"$HERDR_MOCK_LOG"
fixture snapshot.json <<'JSON'
{"result":{"snapshot":{"workspaces":[],"tabs":[],"panes":[],"layouts":[],
  "agents":[{"pane_id":"w1:pB","agent":"claude","name":"fable-2","cwd":"/home/u","agent_session":{"value":"aaaaaaaa-0000-4000-8000-000000000002"}}]}}}
JSON
HOME=/home/u run_event pane.closed
check "a survivor keeps its suffix" "" "$(log)"
check "a gone pane leaves the store" "null" "$(jq -r '."w1:pA"' "$STORE")"
teardown

# ---- Scenario 2: a hand-named agent is left alone and its name is not reused ----
setup
agents_fixture reviewer "" "" ""
HOME=/home/u run_event pane.agent_detected
out=$(log)
check_absent   "hand name untouched"     "$out" "agent rename w1:pA"
check_contains "others still named"      "$out" "agent rename w1:pB fable"
# somebody renames pB by hand afterwards: ours no more
: >"$HERDR_MOCK_LOG"
agents_fixture reviewer mine opus gpt-6-astra
HOME=/home/u run_event pane.agent_status_changed
check_absent "a later hand rename wins" "$(log)" "agent rename w1:pB"
teardown

# ---- Scenario 3: MODEL_ALIASES, and --clear reverts only ours ----
setup
printf 'AGENT_MODEL_NAMES=1\nMODEL_ALIASES=("gpt-6-astra=astra")\n' >"$HERDR_AUTOMATIC_RENAME_CONFIG"
agents_fixture "" "" "" ""
HOME=/home/u run_event pane.agent_detected
check_contains "alias applies" "$(log)" "agent rename w1:pD astra"
: >"$HERDR_MOCK_LOG"
agents_fixture fable fable-2 reviewer astra
HOME=/home/u run_event --clear
out=$(log)
check_contains "clear reverts ours"        "$out" "agent rename w1:pA --clear"
check_contains "clear reverts the alias"   "$out" "agent rename w1:pD --clear"
check_absent   "clear leaves a hand name"  "$out" "agent rename w1:pC --clear"
teardown

# ---- Scenario 4: off by default ----
setup
: >"$HERDR_AUTOMATIC_RENAME_CONFIG"
agents_fixture "" "" "" ""
HOME=/home/u run_event pane.agent_detected
check "AGENT_MODEL_NAMES defaults off" "" "$(log)"
teardown

# A new pane before an existing model-name owner must not claim its name.
setup
agents_fixture reviewer "" "" ""
HOME=/home/u run_event pane.agent_detected
: >"$HERDR_MOCK_LOG"
agents_fixture "" fable opus gpt-6-astra
HOME=/home/u run_event pane.agent_detected
check_contains "new pane avoids an owned name later in the panel" "$(log)" "agent rename w1:pA fable-2"
check_absent "existing owner keeps its name" "$(log)" "agent rename w1:pB"
teardown

t_summary
