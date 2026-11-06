#!/usr/bin/env bash
# Integration test: the engine hands each tab's name to herdr's sidebar as the
# pane tokens $tab_context and $tab_task (see ar_tab_tokens), reporting only a
# change, and only on the snapshot path.

set -o pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tests/lib.sh
. "$here/lib.sh"

ENGINE="$here/../automatic-rename.sh"
MOCK="$here/mocks/herdr"
chmod +x "$MOCK" 2>/dev/null || true

SEP=$(printf ' \342\200\272 ')   # the default CONTEXT_SEP, " › "

setup() {
  SB=$(mktemp -d "${TMPDIR:-/tmp}/hal-test.XXXXXX")
  export HERDR_MOCK_DIR="$SB/fixtures"; mkdir -p "$HERDR_MOCK_DIR"
  export HERDR_MOCK_LOG="$SB/renames.log"; : >"$HERDR_MOCK_LOG"; : >"$HERDR_MOCK_LOG.meta"
  export HERDR_BIN_PATH="$MOCK"
  export XDG_STATE_HOME="$SB/state"
  export HERDR_AUTOMATIC_RENAME_CONFIG="$SB/none.sh"
  export HERDR_CONFIG_FILE="$SB/herdr.toml"
  printf 'agent_panel_sort = "spaces"\n' >"$HERDR_CONFIG_FILE"
  export HERDR_SOCKET_PATH="$SB/herdr.sock"
  export SHELL_NAME=zsh
  unset HERDR_MOCK_VERSION HERDR_MOCK_NO_VERSION HERDR_MOCK_RERUN_ONCE HERDR_MOCK_FAIL_RENAME
  unset HERDR_MOCK_FAIL_VERB HERDR_MOCK_TAB_GONE_AFTER HIDE_SHELL REPORT_TAB_TOKENS
  unset AUTO_INDEX_WORKSPACES AUTO_INDEX_TABS AUTO_INDEX_AGENTS
  unset HERDR_TAB_ID HERDR_PLUGIN_CONTEXT_JSON
}
fixture() { cat >"$HERDR_MOCK_DIR/$1"; }
run_event() { /usr/bin/env bash "$ENGINE" "$1"; }
meta() { cat "$HERDR_MOCK_LOG.meta"; }
teardown() { rm -rf "$SB" 2>/dev/null || true; }

# Two tabs whose labels are already right, so no rename is issued and the
# tokens are the only thing the pass has to say.
#   t1 "[1] dmerr › AI draft": p1 holds no tokens, p2 already holds the right ones.
#   t2 "[2] claude": p3 holds a stale context from an earlier name.
snapshot() {
  fixture snapshot.json <<JSON
{"result":{"snapshot":{
  "workspaces":[{"workspace_id":"w1","label":"[1] api"}],
  "tabs":[
    {"tab_id":"w1:t1","label":"[1] dmerr${SEP}AI draft","pane_count":2,"focused":true,"workspace_id":"w1"},
    {"tab_id":"w1:t2","label":"[2] claude","pane_count":1,"focused":false,"workspace_id":"w1"}
  ],
  "panes":[
    {"pane_id":"p1","tab_id":"w1:t1","focused":true},
    {"pane_id":"p2","tab_id":"w1:t1","focused":false,
     "tokens":{"tab_context":"dmerr","tab_task":"AI draft"}},
    {"pane_id":"p3","tab_id":"w1:t2","focused":false,
     "tokens":{"tab_context":"old","tab_task":"claude"}}
  ],
  "agents":[]
}}}
JSON
}

# ======================================================================
# Scenario 1: tokens split on the last CONTEXT_SEP, reported only on change.
# ======================================================================
setup
export NAME_TABS=0 AUTO_INDEX=1
snapshot
run_event tab.focused
out=$(meta)
check_contains "context and task reported for a pane without them" "$out" \
  "pane report-metadata p1 --source herdr-automatic-rename --token tab_context=dmerr --token tab_task=AI draft"
check_absent   "a pane already holding them is left alone" "$out" "report-metadata p2"
check_contains "a name with no separator clears the context" "$out" \
  "pane report-metadata p3 --source herdr-automatic-rename --clear-token tab_context --token tab_task=claude"
check_absent   "no rename issued for correct labels" "$(cat "$HERDR_MOCK_LOG")" "tab rename"
teardown

# ======================================================================
# Scenario 2: REPORT_TAB_TOKENS=0 reports nothing.
# ======================================================================
setup
export NAME_TABS=0 AUTO_INDEX=1 REPORT_TAB_TOKENS=0
snapshot
run_event tab.focused
check "switched off, no tokens" "" "$(meta)"
teardown

# ======================================================================
# Scenario 3: --clear strips numbers and leaves the tokens alone.
# ======================================================================
setup
export NAME_TABS=0 AUTO_INDEX=1
snapshot
run_event --clear
check "clear reports no tokens" "" "$(meta)"
teardown

t_summary
