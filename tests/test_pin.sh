#!/usr/bin/env bash
# Integration tests for pins and CONTEXT_IGNORE: a tab named as if its pane sat
# in a directory another tool named, and a parent directory that says nothing.
# Same fake-herdr harness as tests/test_context.sh.

set -o pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tests/lib.sh
. "$here/lib.sh"

ENGINE="$here/../automatic-rename.sh"
MOCK="$here/mocks/herdr"
chmod +x "$MOCK" 2>/dev/null || true

SEP=$(printf ' \342\200\272 ')

setup() {
  SB=$(mktemp -d "${TMPDIR:-/tmp}/hal-pin.XXXXXX")
  export HERDR_MOCK_DIR="$SB/fixtures"; mkdir -p "$HERDR_MOCK_DIR"
  export HERDR_MOCK_LOG="$SB/renames.log"; : >"$HERDR_MOCK_LOG"
  export HERDR_BIN_PATH="$MOCK"
  export XDG_STATE_HOME="$SB/state"
  export HERDR_AUTOMATIC_RENAME_CONFIG="$SB/config.sh"
  : >"$HERDR_AUTOMATIC_RENAME_CONFIG"
  export HERDR_CONFIG_FILE="$SB/herdr.toml"
  export HERDR_SOCKET_PATH="$SB/herdr.sock"
  export SHELL_NAME=zsh
  export NAME_TABS=1 AUTO_INDEX=0
  unset HERDR_MOCK_VERSION HERDR_MOCK_NO_VERSION HERDR_MOCK_FAIL_RENAME
  unset HIDE_SHELL TAB_CONTEXT MAX_CONTEXT_LEN SHOW_BRANCH AGENT_TITLES
  export AGENT_TRANSCRIPT=0
  export CLAUDE_CONFIG_DIR="$SB/claude"
  unset HERDR_TAB_ID HERDR_PANE_ID HERDR_PLUGIN_CONTEXT_JSON
  PINS="$XDG_STATE_HOME/herdr-automatic-rename/pins"
}
fixture() { cat >"$HERDR_MOCK_DIR/$1"; }
run_event() { /usr/bin/env bash "$ENGINE" "$@"; }
log() { cat "$HERDR_MOCK_LOG"; }
teardown() { rm -rf "$SB" 2>/dev/null || true; }

# One claude pane, launched in /home/u/work, titled with its task. The optional
# argument is the label herdr currently holds for the tab: the mock never applies
# a rename, so a scenario spanning two passes sets it to what the first one wrote.
claude_fixture() {
  local label=${1:-1}
  fixture snapshot.json <<JSON
{"result":{"snapshot":{
  "workspaces":[{"workspace_id":"w1","label":"claude"}],
  "tabs":[{"tab_id":"w1:t1","label":"$label","pane_count":1,"focused":true,"workspace_id":"w1"}],
  "panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true,"cwd":"/home/u/work",
            "agent":"claude","terminal_title":"Fix the token refresh"}],
  "layouts":[{"tab_id":"w1:t1","focused_pane_id":"p1"}]
}}}
JSON
}

# ======================================================================
# Scenario 1: without a pin the launch directory leads the label; with
#   CONTEXT_IGNORE naming it, the task stands alone.
# ======================================================================
setup
claude_fixture
HOME=/home/u run_event tab.focused
check_contains "launch directory leads the label" "$(log)" "tab rename w1:t1 work${SEP}Fix the token refresh"
teardown

setup
claude_fixture
printf 'CONTEXT_IGNORE=("/home/u/work/")\n' >"$HERDR_AUTOMATIC_RENAME_CONFIG"
HOME=/home/u run_event tab.focused
check_contains "an ignored directory drops out" "$(log)" "tab rename w1:t1 Fix the token refresh"
check_absent   "and leaves no separator behind" "$(log)" "$SEP"
teardown

# ======================================================================
# Scenario 2: pin from inside the pane. The tab reads as if it sat in the
#   pinned checkout, branch included; the pin outlives the pass; --clear undoes it.
# ======================================================================
setup
claude_fixture
printf 'CONTEXT_IGNORE=("/home/u/work")\n' >"$HERDR_AUTOMATIC_RENAME_CONFIG"
repo="$SB/repo/api"
mkdir -p "$repo/.git/refs/heads"
printf 'ref: refs/heads/feat/oauth\n' >"$repo/.git/HEAD"
HOME=/home/u HERDR_TAB_ID=w1:t1 run_event pin "$repo"
rc=$?
check_rc "pin exits 0" 0 "$rc"
check "pin file holds the directory" "$repo" "$(cat "$PINS/w1_t1")"
check_contains "pinned checkout leads the label, branch included" "$(log)" \
  "tab rename w1:t1 api${SEP}feat/oauth${SEP}Fix the token refresh"
: >"$HERDR_MOCK_LOG"
claude_fixture "api${SEP}feat/oauth${SEP}Fix the token refresh"
HOME=/home/u run_event tab.focused
check "a later pass issues no rename (already right)" "" "$(log)"
check "the pin survives the pass" "$repo" "$(cat "$PINS/w1_t1")"
check "the tab is still owned" "true" "$(jq -r '."w1:t1".enabled' "$XDG_STATE_HOME/herdr-automatic-rename/state.json")"
# --tab addresses a tab from outside its pane
: >"$HERDR_MOCK_LOG"
HOME=/home/u run_event pin --tab w1:t1 --clear
check "clear removes the pin file" "" "$(ls "$PINS" 2>/dev/null)"
check_contains "clear hands the tab back to its own directory" "$(log)" "tab rename w1:t1 Fix the token refresh"
teardown

# ======================================================================
# Scenario 3: refusals. No tab, a relative path, and a pin file holding
#   garbage are all ignored rather than named.
# ======================================================================
setup
claude_fixture
run_event pin /home/u/work/code/api 2>/dev/null
check_rc "no tab id is refused" 2 "$?"
HERDR_TAB_ID=w1:t1 run_event pin code/api 2>/dev/null
check_rc "a relative path is refused" 2 "$?"
mkdir -p "$PINS"; printf 'not a path\n' >"$PINS/w1_t1"
HOME=/home/u run_event tab.focused
check_contains "a garbage pin is ignored" "$(log)" "tab rename w1:t1 work${SEP}Fix the token refresh"
teardown

# ======================================================================
# Scenario 4: the pin goes when the tab does.
# ======================================================================
setup
claude_fixture
mkdir -p "$PINS"; printf '/home/u/work/code/api\n' >"$PINS/w1_t1"; printf '/home/u/x\n' >"$PINS/w1_t9"
HOME=/home/u run_event tab.focused
check "a live tab keeps its pin" "/home/u/work/code/api" "$(cat "$PINS/w1_t1")"
if [ -f "$PINS/w1_t9" ]; then pin_rc=0; else pin_rc=1; fi
check_rc "a gone tab loses its pin" 1 "$pin_rc"
teardown

# ======================================================================
# Scenario 5: the fast path honors the pin too.
# ======================================================================
setup
export TAB_CONTEXT=1 HERDR_TAB_ID=t1 HERDR_PANE_ID=p1
mkdir -p "$XDG_STATE_HOME/herdr-automatic-rename"
printf '{"t1":{"auto":"zsh","enabled":true}}\n' >"$XDG_STATE_HOME/herdr-automatic-rename/state.json"
fixture tab_t1.json <<'JSON'
{"result":{"tab":{"tab_id":"t1","label":"zsh"}}}
JSON
mkdir -p "$PINS"; printf '/home/u/work/code/api\n' >"$PINS/t1"
run_event precmd zsh
check_contains "precmd names from the pin, not \$PWD" "$(log)" "tab rename t1 api${SEP}zsh"
teardown

t_summary
