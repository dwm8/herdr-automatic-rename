# Changelog

All notable changes to herdr-automatic-rename are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/), and the project uses [semantic versioning](https://semver.org/).

## [Unreleased]

## [0.11.1] - 2026-09-11

This release of the dwm8 fork includes upstream 0.11.0 and the fork's tab pins, Codex transcript titles, ignored context directories, and model-based agent names.

### Changed

- Model-based agent naming joins ownership records once per panel instead of running two additional JSON lookups per named agent on each event. Settled names keep their state file and issue no rename.

### Fixed

- A new agent earlier in the panel avoids a model name already owned by an agent later in the panel, preventing a rejected duplicate rename.
- Tab pins survive an incomplete tab-list read, following upstream's ownership-state safeguard.

### Added

- A tab can be pinned to a directory by another tool: `automatic-rename.sh pin <directory>` from inside the pane (or `--tab <id>` from anywhere), `pin --clear` to undo. The tab is named as if its pane sat in that directory, branch included. It exists for agents launched from a parent directory and working across the repositories under it: Claude Code started in `~/work` reports `~/work` as its cwd however far afield it edits, so a hook that watches which files it touches is what knows where the work is, and this is how it says so. Pins live beside the state file and are pruned with it; ownership, hand renames, and `reset` are untouched.

- Codex tabs are named from the thread's own rollout file, the way Claude tabs are named from their transcript. Codex titles its terminal with the directory name, which the plugin already refused, so every Codex tab read `codex`. The first prompt the user typed is the task, and that is what the tab reads; the AGENTS.md instructions and environment context Codex files under the same role are recognised and skipped. Needs `herdr integration install codex`, which is what tells herdr which thread a pane holds.

- `AGENT_MODEL_NAMES=1` names each agent in herdr's agents panel after the model its session is running, read from the transcript the way the task is: `fable`, `fable-2`, `opus`, `gpt-6-astra`. herdr's own name for the agent is the program, and three panes running `claude` on three different models read alike there. herdr refuses a duplicate agent name, so a second agent on the same model takes a suffix and keeps it. A name you gave an agent yourself is never touched, and `clear` reverts only the names this wrote. `MODEL_ALIASES` maps a model id to the name you would rather see. Off by default.

- `CONTEXT_IGNORE`, directories that say nothing the way the home directory says nothing. The entry worth making is the directory every project is checked out under, so a bar of agent tabs launched there stops reading `work › ...` on every one.

## [0.11.0] - 2026-09-10

### Added

- Workspace labels can be shown under a shorter name than their directory carries. `WORKSPACE_SUBSTITUTE_SETS` is an ordered list of `sed -E` rewrites applied to the name herdr derives from the directory, so `'s|^worktree-|wt-|'` puts `worktree-feature` in the sidebar as `wt-feature`. The rewrite reaches the label and nothing else: the directory and the Git worktree keep their names, and a tab inside that directory still drops the workspace's name out of its own label rather than re-injecting the long spelling it was shortened to lose.

  Only a derived name is rewritten. A name you typed is left alone for good, the same promise the tab opt-out makes, with the same gap in it: herdr exposes no way to tell a typed name from the derivation it happens to match exactly.

  Numbering and rewriting are the two reasons the workspace pass runs, so a rewrite reaches a workspace whose numbering was never turned on. A rewrite is derived fresh every pass rather than built out of the label the last one wrote, so deleting the rules puts the derived names back at the next event by itself. With numbering off there is no next pass to do that, and the labels keep their last rewrite until `clear`.

  `clear` hands back the derived name too, where it used to strip the number off the rewrite and leave that standing. It is documented as the last step before uninstall, after which the plugin that could have restored the label is gone.

  Based on [#15](https://github.com/qu8n/herdr-automatic-rename/pull/15) by @engineersamuel.

## [0.10.0] - 2026-09-10

### Added

- One command installs the plugin and the shell hook: `curl -fsSL .../install.sh | bash`. The hook is what makes a rename land the moment a command starts, and wiring it was a per-shell copy-paste out of the README, so anyone who read past step 1 got the numbering and none of the naming until they matched their shell to the right snippet. `install.sh` reads `$SHELL`, writes the zsh, bash, or fish snippet to that shell's startup file, and installs the plugin first when herdr does not already list it.

  A marker comment in the startup file is what makes a re-run change nothing, so the command doubles as the upgrade path. The snippet it writes globs herdr's managed plugin directory, whose name carries a version hash, and spells the home directory as `$HOME` so the startup file survives being carried to another machine. A shell argument (`bash install.sh fish`) wires a second shell and `HAR_RC` names a startup file other than the default, which is what a macOS login shell reading `~/.bash_profile` needs. Run from a clone rather than curl'd, the hook points at the checkout and the plugin half is left alone, since herdr owns that copy.

  The two steps it will not take behind your back, turning off herdr's new-tab name prompt and installing the agent integrations, it prints when it finishes. The manual snippets are still in the README, folded away.

- A `doctor` action. It runs one real naming pass with tracing on and prints, for the current tab, the versions and paths in play, the tab's ownership record, the label it carries, and every decision that pass made about it. Until now every failure looked the same from outside: nothing happened. A tab that opted out after a hand rename, a placeholder deferred, a title refused, a lock held by a dead process, and a `jq` that was never installed all produced the same silence, and the issues filed against this plugin were mostly the reporter reasoning backwards from that silence. `herdr plugin action invoke herdr-automatic-rename.doctor` runs it, and the README has a Troubleshooting section keyed to what the tab bar shows.

  `AR_TRACE=1` in herdr's environment writes the same decisions for every pass to `trace.log` in the state directory, at 0600 since a label can carry a task title.

### Fixed

- Ownership records survive a pass that could not read everything. A tab whose record goes missing reads as renamed by hand on the next pass and opts out of naming for good, so every path that dropped one without cause was a permanent bug. A workspace whose tab list failed to read had every tab pruned. An empty workspace keep list pruned every workspace record. A store with one hand-edited key emptied every record after it. A `jq` that crashed read as a broken file and healed a good store to nothing, and on Debian's jq 1.6 a truncated file was never healed at all, since that release reports a parse error with a different status. Each of those now leaves the records alone, and the store is rewritten only when a record actually changed rather than on every event.

- The shell hook scrubs the workspace name it derives from `$PWD`. A directory name holding a control character reached `herdr workspace rename` raw. herdr handed the label back normalized, which read as a name somebody typed and opted the workspace out of directory tracking, with no `reset` to bring it back. The tab half already scrubbed for this and the workspace half now does the same.

- `agent_panel_sort = "spaces"  # or "priority"` in `config.toml` reads as `spaces`. The comment used to be part of the value, and the word `priority` anywhere on the line stripped every agent number.

- `SUBSTITUTE_SETS` is documented as acting on the program name or command line, which is what it does. The comment said the final label, and PR #15 was written against that wording. The README says that untitled Claude Code tabs are named by reading the session transcript, and how to turn that off, and it writes `MAX_TITLE_LEN`'s default as the derivation it is rather than the number it happens to be.

### Changed

- A steady-state event spawns fewer processes. The state file is read once per pass rather than once per tab, `herdr --version` is asked once per process, the rename the plugin itself issues no longer buys a second full pass through the `tab.renamed` event it fires, and the wait for a closing tab backs off over about two seconds instead of polling sixty times.

- The test suite runs its files in parallel, about twenty seconds instead of forty-five. `./tests/run.sh --serial` restores the old order. CI pins its actions by commit and checks the shellcheck download against a recorded digest, and markdownlint now refuses an em dash, which `CONTRIBUTING.md` already did.

## [0.9.1] - 2026-09-09

### Fixed

- Workspace numbers follow a collapsed space again on herdr 0.9.0. That release moved the terminal UI into each client and the sidebar's collapse state with it, so the array the plugin read, `collapsed_space_keys` in `session.json`, is now written empty whatever the sidebar shows. Every collapsed space read as expanded: the hidden rows kept a number no keybind reaches, and every row below one carried a number that jumped somewhere else.

  Collapse is read from the file the client writes it to instead, `client-shell/local-<hash>.json` under herdr's state directory, whose name is the FNV-1a 64 of the client socket path herdr derives from the socket path it already exports to us. An older herdr writes no such file, which is what picks the source: the file that is there, not a version test, so numbering on herdr below 0.9.0 is unchanged. The agent panel's sort order moved the same way and is read the same way, which matters only to a herdr old enough to number agents at all.

  The click now reaches the plugin faster than it did. herdr wrote `session.json` on a five-second debounce and writes this file the instant a space is toggled, so the pass that runs after the click reads the new value rather than the old one. Two limits are new. The file is one per session socket rather than one per client, so two clients on one session share it and the last writer wins. A client narrow enough for herdr's mobile layout ignores collapse altogether, without writing that down anywhere.

- A Muse tab is named after the agent. herdr 0.9.0 detects Muse, which installs as `muse-bin-<version>` and never runs under a plain name, so a pane herdr had not yet detected reached the tab bar as `muse-bin-0.1.0-R708.1` wearing the glyph for an unknown program. The versioned name is folded onto `muse` the way herdr folds it, a digit required after the prefix so an unrelated `muse-binary` keeps its own name. The fold runs ahead of the alias lookup, the program lists and the icon map, so one `PROGRAM_ALIASES` entry names Muse however it was installed. `muse`, `muse-cli` and `muse-code` are listed alongside the other agents.

## [0.9.0] - 2026-09-08

### Added

- An agent's title is condensed into its keywords instead of shown with the tail cut off. `MAX_TITLE_LEN` takes the END off a title, which is where the words saying WHICH task this is tend to sit: "Investigate why the nightly ETL job drops rows" reached a tab as "Investigate why the nightly". `TITLE_CONDENSE=1` drops a leading verb and the filler and joins what is left, so the same budget carries "nightly-ETL-job-drops-rows".

  It selects rather than generates. The words are the agent's own, in the order it wrote them, on the reasoning that it put the salient ones first. `TITLE_LEAD_VERBS` and `TITLE_FILLER_WORDS` are the two lists, measured against the last title Claude Code generated in each of 65 titled sessions rather than written from imagination, and `TITLE_WORD_SEPARATOR` and `TITLE_CASE` say what the surviving words are joined and cased with. A condensed label is charged to `MAX_TITLE_LEN` like any other, the icon glyph and its space reserved out of it first.

  Off by default, so a config that does not name it renders exactly what `AGENT_TITLES` rendered before. A title that condenses to nothing is left as the sentence, and so is one whose label would come out longer than the prose or wearing a leading "[12]", the shape a tab number has.

- The agent is shown alongside its task, `cc:auth-flow` where a tab read `auth-flow`. Which agent is on a task was not recoverable from an agent tab: every agent herdr detects draws the same robot glyph, deliberately, and a title then replaced the one place the program name appeared. That costs a session running one agent nothing, and in a session running three it is what tells two tabs apart.

  `TITLE_STYLE=name_and_task` asks for it and `PROGRAM_ALIASES` applies, since asking for the name is asking for the name you chose for it. The name and its colon are charged to `MAX_TITLE_LEN`, so the task gives up the characters rather than the tab growing. The prefix is all or nothing: it goes in only where the budget seats the name, its colon and `MIN_TASK_LEN` characters of task, and otherwise the name is what goes, because this asks for the task with the name added rather than the other way about. The glyph and its space are part of that budget where icons are on, and an alias carrying a space is never used as a prefix, truncation having cut such a name in half and left the tab reading a fragment of it.

  Off by default. A refused title is not prefixed either, "cc:cc" saying nothing twice.

### Fixed

- The workspace name follows the shell's directory ([#20](https://github.com/qu8n/herdr-automatic-rename/issues/20)). A `cd` emits no herdr event, so a workspace kept the name of the directory it was created in until something unrelated woke the plugin, while the tab beside it moved at the next prompt. The shell hook is the one thing that does fire on a cd, and it renamed only the tab.

  It now names the workspace from the same prompt, by the rules the reconcile uses: the directory is the shell's own `$PWD`, the base is the repository that directory belongs to or the directory itself, and a workspace somebody named by hand is numbered and nothing else. A quiet prompt costs one state read and no herdr call, since the base we own is recorded and only a cd that leaves the project has anything to ask. A workspace the plugin has not adopted is left to the next event, adopting one meaning a round-trip on every prompt.

  Only the tab the workspace is on moves it, since herdr tracks a workspace's directory through its active pane and a prompt drawn in a background tab is about somewhere else. Panes with no shell hook installed are unchanged, and so is the five-second wait for herdr to persist a brand-new workspace.

- One `PROGRAM_ALIASES` entry now names an agent however it was installed ([#19](https://github.com/qu8n/herdr-automatic-rename/issues/19)). Two agents answer to two names, `cursor-agent`, which herdr calls `cursor`, and `kiro-cli`, which it calls `kiro`, and which of the two reaches naming says only how the agent was installed. A native install arrives as its own executable, an npm-fronted one as the kind herdr detected behind the runtime. Keyed by exact name, one config labelled the two panes differently: `cu` where the alias matched, `cursor` where it did not.

  An alias is now looked up under both spellings, the exact name first, so a config naming each separately still gets each. The pair is read off the agent list that already carries both spellings rather than out of a second table somebody would have to keep in step with it.

- Two herdr sessions no longer share one state store ([#22](https://github.com/qu8n/herdr-automatic-rename/issues/22)). Every server numbers its tabs from `w1:t1`, so the plugin running under `herdr --session work` and the one under `herdr --session home` wrote the same keys into the same `state.json`, and each full pass pruned the other session's tabs as closed. A tab whose record is gone reads as renamed by hand on the next pass and opts out of naming until reset, which is how a machine running more than one session ended up with every tab frozen on whatever it was called when the other session last ran, and the lock they also shared dropped events on top of that.

  A named session now keeps its store under `sessions/<name>/` inside the state directory, resolved the way the herdr CLI picks its server: from the session directory in the socket path herdr exports to plugin commands and pane environments alike, or from `HERDR_SESSION` when no socket path is set, so the herdr-invoked pass and the shell hooks resolve one file. The default session keeps the store where it always was.

  Upgrading costs nothing in the common case. A named session's store is created once from the owned records of the old shared one, so a tab the plugin was naming goes on being named. A record the shared store got wrong, which on a multi-session machine is most of them, ends where an empty store would put it: a tab whose label matches nothing the store owns is opted out, and the reset action or clearing the label hands it back as before. Nothing removes a session's store when the session is deleted, and the old shared file stays as the default session's; both are safe to delete by hand.

## [0.8.0] - 2026-08-28

### Added

- A tab is named after where the work is, not only after what is running there. The label reads `[N] <directory> › <branch> › <activity>`, so five `claude` tabs across three checkouts stop reading alike. Each part drops out when it says nothing worth the width: the directory when it is your home directory, the filesystem root, or the name of the workspace the tab is already in, since herdr shows that above the tabs. `TAB_CONTEXT=0` turns the whole half off, and every part keeps a budget of its own rather than sharing one total.

  A directory too long for `MAX_CONTEXT_LEN` is reduced rather than cut through the middle. Worktrees and branches are named the same way by the same people, so `bugfix-proj-482-fix-rev-discrepancy` reads as `PROJ-482` where a plain cut leaves `bugfix-proj-`, which identifies nothing.

- The branch the pane's repository has checked out, read from the files under `.git` and never by running git. `git rev-parse` is a process where `HEAD` is one open, and this runs per named tab on every herdr event and again on every shell prompt. The repository's own default branch is left out, read from `refs/remotes/origin/HEAD` rather than from a list of names, so a team whose trunk is `develop` gets the same silence a `main` one does. A repository that records no default falls back to `TRUNK_BRANCHES`, because otherwise every tab of a local-only repo carries `main` alike.

  Worktrees and submodules are followed through their `gitdir:` pointer to their own HEAD and through `commondir` to the shared refs. A rebase keeps the branch it set aside, so a tab does not take a new hash on every step; any other detached HEAD shows the short hash, which is where commits get lost. A branch that repeats the directory or the workspace is dropped, since a worktree named after its branch would otherwise say one thing three times. `SHOW_BRANCH=0` and `MAX_BRANCH_LEN=0` both leave branches out.

- A pane running `ssh` is named after the machine it reached, `prod-01 › ssh`. The directory it was launched from is local and the branch checked out there would read as the remote machine's, so both are dropped. The destination is parsed rather than taken as the first word after `ssh`, which is as often an option's value as a host: clustered short options, attached values, the url form, and bracketed IPv6 addresses all resolve, the user and the port are dropped, and a `-o` setting whose value is a command is refused outright rather than guessed at, because a `ProxyCommand` parses as its own bastion.

- A coding agent that has not titled its terminal is named from its own session. Claude Code derives that title from what the user typed, so a session opened with a slash command and answered by the agent alone is never given one, and its tab read `claude` for as long as it ran. The transcript is read for the title the agent generated, or failing that the first prompt the user actually typed, which is what Claude Code's own session list shows for an untitled session.

  Only Claude Code is read, and only where herdr reports that pane's session, which `herdr integration install claude` is what sets up. Reads are bounded to the end of the file each answer needs. `AGENT_TRANSCRIPT=0` leaves the file unread, and a transcript that stops carrying these fields yields nothing, so the tab is named as it was before this existed.

### Fixed

- A numbered workspace goes on following its directory ([#13](https://github.com/qu8n/herdr-automatic-rename/issues/13)). herdr names a workspace after `identity_cwd`, its own tracked directory, and the first `workspace rename` freezes that name for good: herdr keeps the directory current and never labels from it again. Numbering a workspace pinned it to whatever it was called when it opened, and no smaller rename would have helped, because there is no rename that leaves the derivation alive.

  The base now comes from `identity_cwd`, read out of the `session.json` the collapse rules already read, and resolves to the repository the directory belongs to, or to the directory itself outside a repo. A pane moving around inside a project is not a rename; a pane that leaves takes the new name. Two caveats come with the file. The value is in no API response, and herdr saves it on a 5-second debounce, so a `cd` lands on the label an event or two later rather than instantly. An older herdr without the field keeps the previous behavior.

  A workspace herdr has not written to `session.json` yet, which is every new one for up to five seconds, reads its directory off its panes instead. Without that, the numbering rename lands before the file exists, the stale label reads as a name somebody typed, and the workspace opts out of tracking for good.

  A `cd` still emits no event the plugin subscribes to, so the new name lands on whatever event arrives next, the same way a sidebar collapse does.

  A workspace named by hand, or by another plugin, keeps its name and is only ever numbered, which is the promise a tab already gets. The plugin tracks a label that is herdr's own derivation or its own last write, and nothing else. Renaming a workspace back to the directory name hands tracking back, since `reset` takes a tab and a workspace has no equivalent.

## [0.7.3] - 2026-08-22

### Fixed

- Tab naming could stop for a session, or for half a minute at a time, and say nothing either way. Both come from the lock that keeps one reconcile pass running at a time. Its 30-second steal was three filesystem calls, so two passes that found the same abandoned lock could both come away holding it: each writes the whole state file, one overwrites the other's record of which tabs it named, and a tab whose record is gone reads as renamed by hand on the next pass and opts out for good, recoverable only through the reset action. Stealing is now a move, an immediate reservation of the lock path, and only then the question of whether what was moved was really abandoned. Against six processes racing one abandoned lock, that is the difference between two holders in roughly a third of bursts and somewhere between none and one in a hundred.

  The same rewrite turned up three ways to leave a lock that no process holds and none may steal until it ages out, which stops every event in between. A lock whose owner token could not be written was left behind rather than given back, and no race is needed to reach it: a umask of 222 does, and so do a full disk, a quota, and a read-only mount. The hand-back that returns a lock to a live holder truncated its token before reading it, and printed its own failure onto your prompt. And the move that starts a steal did not check its destination was free, where an existing one makes it nest the lock instead of renaming it, out of sight of everything that follows.

- A `state.json` that `jq` cannot read no longer ends tab naming for the session. Every write started from the file already on disk, so one that would not parse failed every write for as long as it sat there, and the reset action could not recover the tab either, because re-adopting one is another write. It renamed the tab once, recorded nothing, reported "Nothing to reset", and the next event went back to doing nothing. Missing and unreadable are now the same answer, and the check insists on exactly one JSON object: `jq` reads top-level values as a stream, so a file holding two of them parsed, and writers handed the pair updated each document and wrote both back, leaving it broken for good.

  Healing the file does not hand a tab its name back, and cannot. A tab whose record went with the file has a label matching nothing state knows, which is exactly what a hand rename looks like. What changes is that the opt-out is recorded, so reset works again.

### Changed

- `make lint` can fail. Its recipe was `command -v shellcheck && shellcheck ... || echo skipping`, and a real warning took the `||` branch too, so the target printed "shellcheck not installed" and exited 0. `make lint-md` had the same shape, so a hard-wrapped line reported itself as a missing npx. CI now runs shellcheck as well, over the same file list, and its syntax check covers every bash file in the repo rather than three of them.

## [0.7.2] - 2026-08-20

### Fixed

- An oh-my-pi tab showed the agent's spinner glyph and renamed itself on every status change. Most agents park a status glyph in front of the task and the existing strip takes it off; oh-my-pi puts its own brand there first and the glyph second: `π ⠋ Fix the parser` while it works, `π > Fix the parser` when the turn is yours, `π ! ...` when it wants you, `π: ...` with its title state off. The strip only takes a leading run of non-alphanumerics and jq reads the brand as a letter, so it stopped on character one and each state reached the tab as a different label ([#12](https://github.com/qu8n/herdr-automatic-rename/issues/12)).

  `TITLE_BRANDS` names a brand per herdr agent kind (`pi` and `omp` by default, both the same program) and it comes off before the strip runs, at the very front only and only with a non-alphanumeric behind it, so `πcalc rewrite` keeps its first letter. Every state now reduces to the same label, so nothing renames on a status change. The reported case gets more than the glyph back: with no session title yet oh-my-pi labels itself after its directory, which the directory refusal already knew to hand to the program name. It just could not see it behind the brand.

## [0.7.1] - 2026-08-19

### Fixed

- A Qwen Code or `maki` tab was missing from the lists keyed by program name. herdr `0.8.2` detects `qwen` as an agent kind, and Qwen Code installs from npm, so its pane fronts as `node` and takes the `WRAPPER_PROGRAMS` path that names a tab from herdr's detection: naming needed nothing. The two program lists did. With `ICONS_ENABLED=1` a `qwen` tab drew the `?` fallback instead of the agent glyph, and with `SHOW_PROGRAM_ARGS=1` a natively installed `qwen` showed its whole command line. `maki`, a kind herdr added in `0.8.0`, was missing from both the same way. Qwen's title needs no new rule: it parks a status glyph in front of the task (`✳`, `◐`), which the existing strip takes off, and the no-task title `Qwen Code` is already refused as the agent kind plus `code`.

  The icon test reads its roster out of `NAME_ONLY_PROGRAMS` now rather than repeating it, so the next agent added to one list and not the other fails the suite instead of shipping. That is how `maki` went two herdr releases with the fallback on its tab.

### Documentation

- The README covers herdr `0.8.2`'s `ui.window_title`, on by default at `{hostname}: {workspace}` and so already carrying a workspace's `[N]` prefix. Adding `{tab}` puts the generated tab name in the outer terminal's title, a surface the plugin cannot write itself.
- The README notes that herdr `0.8.2` searches renamed single-tab labels, so the Session Navigator finds a tab by the name this plugin wrote.

## [0.7.0] - 2026-08-18

Names a tab running a coding agent after the task the agent reports: `Squash merge command` instead of a fifth tab reading `claude`. herdr publishes the title on the pane object the reconcile already holds, so the label costs no extra herdr call. It follows the work on an event the plugin already subscribes to, so nothing polls for it.

A tab with more than one pane is named after the pane that matters. For the usual agent-and-shell split that is the agent, not the half you happen to be typing in. Several naming bugs go with it: a background split kept the name it had before the split, a tab whose rename herdr rejected was never named again, and a label carrying a backslash or a control character reached herdr mangled.

Upgrade note for anyone running a coding agent in a tab. `AGENT_TITLES` defaults to on, so those tabs stop reading `claude` and start reading the task. Set `AGENT_TITLES=0` to keep the program name. `MAX_TITLE_LEN` (28) and `TITLE_IGNORE` tune what gets through.

### Added

- A tab running a coding agent is named after the task the agent reports rather than after the agent (`AGENT_TITLES`, default on). Naming by foreground program has one case it cannot answer: five `claude` tabs all read `claude`, and the tab bar stops being a way to find anything. A coding agent already publishes the task as its terminal title and keeps it current, so that is what the tab shows. herdr publishes the title on the pane object the reconcile already holds, so reading it costs no extra herdr call on any version, and a tab named this way needs no `pane process-info` at all, which leaves an agent-heavy session making fewer herdr round-trips than before. The label follows the work on `pane.agent_status_changed`, an event the plugin already subscribes to.

  A title only replaces the program name when it says something. `ar_title_clean` refuses three kinds that say nothing: one naming the agent instead of its work (the agent's own herdr kind, that kind followed by `code`, or a `TITLE_IGNORE` entry, which is what an agent titles a session it has no task for yet), one that is just the directory the pane sits in, and a bare number, which is herdr's own generated tab label handed back through the title. Every refusal falls through to the program name, `PROGRAM_ALIASES` and the `WRAPPER_PROGRAMS` unwrapping included. A path to that directory is refused the same way, since an agent titling itself `~/dev/api` is still naming where it sits. Only a title with no whitespace, though, because a description like `Fix build for services/payments` also ends in a directory name and is still the work. Every comparison is made against the title in the shape the tab would carry it, so a trailing space cannot walk a refused title past them.

  A title that survives replaces the program name outright, alias and all: `AGENT_TITLES` is the request for the task, and an alias shortening `claude` to `cl` is not a request to hide the work. The program still supplies the icon, and the label gets its own budget, `MAX_TITLE_LEN` (28) rather than `MAX_NAME_LEN` (20), cut at a word boundary when that leaves at least half of it. A title is a sentence, and 20 characters were sized for command names.

  Before any of that, the leading run of non-alphanumerics comes off. herdr keeps an ANSI-stripped copy of the title and stripped means exactly that: an agent parks a spinner glyph in front of its title while it works, and claude cycles four of them. Without the strip the label would flip between `Task` and `<glyph> Task` on every status event, and each flip is a rename. `jq` does that strip, and the case-folding for the comparisons, in one call, because its character classes know Unicode: a byte-wise strip under the C locale herdr may launch a plugin in would eat the first letter of a title that opens with a non-ASCII word. The function still takes strings and returns strings, which is what keeps it in `naming.sh`.

- A tab with more than one pane is named after the pane that matters. Naming it from its own focused pane, which is what the layouts fix below gives it, still read the wrong half of the usual agent split. An agent sits in one pane and a shell in the other, and focus is in the shell most of the time, so the tab advertised `zsh` while the interesting thing sat beside it. The pick is now, in order: the tab's own focused pane when herdr reports an agent in it, then any pane of the tab holding an agent that is working or blocked, then the focused pane. So a split stays about the agent while you read or type in the shell half, and an idle agent stops at the second rule on purpose, since a finished agent should not hold the name of a tab you have moved on to. The choice is made in the snapshot reshape and travels on the tab row as `_name_pane`, so the tab loop costs nothing extra for it. A herdr whose snapshot carries no layouts can answer neither the first rule nor the third, since both ask for the tab's own focused pane. The second asks only for an agent at work, so it still answers there, and everything it does not answer falls to the older inference (the sole pane of a single-pane tab, else the tab's own focused pane).

- The `reset` and `clear` actions report what they did as a herdr notification. Both are built for a keybinding, where the only feedback was the tab bar redrawing. A `reset` that found no tab to re-adopt, or that ran under `NAME_TABS=0`, looked exactly like one that worked, and `clear` on an already clean session looked like nothing at all. Each outcome now names itself. A re-adoption is reported only when both halves happened: the tab had opted out (read before its state is cleared) and it is named and owned again by the end of the pass. Reporting it from the first half alone told the user naming was back on even when the rename that followed failed, and a tab in that position opts itself straight back out on the next event.

  Both actions also wait for the lock instead of deferring to whoever holds it. Events can defer, because any pass computes the same names, but an action carries a request that lives in its own process, so handing the job over dropped it: a reset pressed during a burst of events did nothing at all, and reported nothing either, since the deferral exited before the notification. Best effort, so a herdr without `notification show` declines it and the action still does its work; the uninstall path (`--clear`) notifies through the same helper.

### Fixed

- Running the test suite inside a herdr pane renamed that session's tabs. The hook tests source the real hooks, and a hook resolves the real engine next to itself, so with `HERDR_TAB_ID` inherited from the pane and nothing pointing the engine at the fake herdr, every hook call the tests made went to the live session. They run fully sandboxed now.

- A tab whose rename herdr rejected stopped being named at all. Ownership was recorded before the rename was issued, so a failed one left state claiming a base the tab did not carry; the next pass read the mismatch as a name typed by hand and opted the tab out for good, recoverable only through the `reset` action. Ownership is now recorded for a name the tab actually carries: the label already matches, or the rename reported success. The shell-hook fast path has always ordered it this way.

- A background tab with more than one pane kept the name it had when it last had a single pane, so a split that started an agent still read `nvim`. Naming had no pane to read: none of a background tab's panes carries `.focused`, and the pane list is all the pass looked at. It now takes the tab's own `focused_pane_id` from the snapshot's `layouts`, which answers for every tab. Older herdr, whose snapshot has no layouts, keeps the previous behavior, except for a tab with an agent at work in it, which the rule above names without asking for a layout.

- The focused tab was named from the GLOBALLY focused pane, which belongs to whichever client moved focus last. With a second client attached, or a remote attach, that pane can sit in a different tab. Per-tab layouts remove the guess, and the pane-list fallback now reads only the tab's own panes. A focused tab with several panes and no focused pane of its own, which is what that same second client looks like on a herdr with no layouts, keeps the label it has rather than being named after an arbitrary one of them.

- Where herdr named no foreground process group at all but still reported one process for the pane, no name was computed. Some Linux container and sandbox setups cannot expose a foreground group, which is what left tab naming doing nothing there. A single reported process is not a choice, so such a pane is now named after it. Two or more with no named group would be: herdr does not order that list and documents its own degraded detection as one where a background job can look like the foreground one, so those panes keep the label they have. A group herdr DID name whose process is absent from the list is a group racing its own exit, and still computes no name; so does a pane herdr reports no process for.

- A label carrying a control character reached herdr verbatim: `argv` can hold a newline or a tab, so `SHOW_PROGRAM_ARGS=1` could put one in the tab bar. They are now replaced where they arrive, in the jq that reads `pane process-info`, and the label has its whitespace runs collapsed and its ends trimmed before truncation. A clean label, which is nearly all of them, costs no extra process.

  The two values that reader returns travel one per line now rather than as TSV. `@tsv` escaped a real tab into the printable two characters `\t`, which no scrub downstream can tell from text somebody typed, and it doubled every backslash in a command line on the way past.

- A tab carrying no label at all was never named again. Its row had an empty field in the middle, and the rows were split on a tab, which bash counts as whitespace: `read` collapses a run of them, so every field after the empty one shifted and the tab read its own pane count as its label. `HIDE_SHELL=1` with numbering off is exactly that state, so a tab blanked once stayed blank however many programs ran in it. Rows are split on the ASCII unit separator now, which keeps an empty field in place; nothing can carry one, since the values have their control characters removed on the way out of jq.

- A name this plugin owns is now written until herdr holds exactly it. Rows arrive with control characters replaced, so a label carrying one read as equal to the name computed for it and no rename looked necessary, which left the character there for good. A label the plugin does NOT own is still left exactly as the user typed it.

- Numbering a tab whose name holds a backslash rewrote that name. Every row the reconcile reads came back through `@tsv`, which doubles a backslash, so a tab called `C:\temp` was renamed to `C:\\temp` (workspace and agent rows read the same way). Rows now carry their values unescaped and drop control characters instead, which is what keeps them parseable. The same change lets a tab whose label carries a control character stay owned: escaped, it matched nothing this plugin had recorded and the tab read as renamed by hand.

## [0.6.1] - 2026-08-14

### Fixed

- An agent whose entrypoint is an interpreted script named its tab after the interpreter. An npm bin shim is a JS file behind a node shebang, so the kernel execs the runtime and the pane's foreground process is `node` on every platform: a codex pane read `node`. Before 0.2.3 the same pane read `MainThread`, because the resolution chain then had no argv[0] step, so a Linux pane (no argv0) fell through to the process's `name`, which for node is its thread name; the #6 fix moved these tabs from `MainThread` to `node`. A pip or pipx installed agent hits the same thing through `python`, its console script being a shebang file too. (An agent whose package ships or execs a native binary, claude and opencode among them, reports its own name and was never affected.)

  Where the foreground program is a language runtime or package runner (the new `WRAPPER_PROGRAMS` list) and herdr has detected an agent in that pane, herdr's answer is used instead and the tab reads `codex`. The agent is read off the pane objects the reconcile already holds, since herdr publishes its detection result on the pane itself, so the lookup costs no extra herdr call on any version.

  Both conditions are required, so a plain `node server.js` tab keeps its name, and an agent that reports its own name never consults the pane's agent field. Identification stays herdr's job on purpose: its detector already unwraps runtime-fronted agents, so a pane it cannot identify is an upstream detection gap, not something this plugin second-guesses from `argv`.

## [0.6.0] - 2026-08-13

Splits the `[N]` jump-key numbering by item kind. `AUTO_INDEX_WORKSPACES`, `AUTO_INDEX_TABS` and `AUTO_INDEX_AGENTS` each override `AUTO_INDEX` for one kind of row, so numbered tabs above plain workspace names is one line of config.

Nothing changes for a config that names none of the new knobs. `AUTO_INDEX` still switches all three kinds together.

### Added

- `AUTO_INDEX_WORKSPACES`, `AUTO_INDEX_TABS` and `AUTO_INDEX_AGENTS` split the `[N]` numbering by item kind ([#8](https://github.com/qu8n/herdr-automatic-rename/issues/8)). Each defaults to `AUTO_INDEX` and overrides it when set, so numbered tabs above plain workspace names is `AUTO_INDEX_WORKSPACES=0` on its own. Existing configs are unaffected.

### Changed

- Setting one of the new per-kind knobs to `0` strips the `[N]` already on those rows at the next event, instead of leaving them until the `clear` action.

  Only a knob you set does this. The strip cannot tell a prefix this plugin wrote from one you typed, so a hand-picked `[1] incident` would lose its bracket, and naming the kind is how you ask for that. A config carrying only `AUTO_INDEX=0` never triggers it: workspace and agent labels there are left alone, exactly as before. Tabs are the one kind already stripped this way whenever `NAME_TABS=1`, and that is unchanged. Only all-digit brackets are ever touched; `[wip] deploy` is safe throughout.

## [0.5.0] - 2026-08-07

Grows the icon map from 9 entries to ~170 and makes it configurable, with `ICON_FALLBACK` for programs it does not know and `ICON_MAP` for per-program overrides.

Upgrade note for anyone already running `ICONS_ENABLED=1`: programs outside the map now show a `?` where they previously showed no glyph at all. Set `ICON_FALLBACK=''` to keep them text-only.

### Added

- The icon map moved out of `naming.sh` into `icons.sh` and grew from 9 entries to the full `tmux-nerd-font-window-name` map (its [`defaults.yml`](https://raw.githubusercontent.com/joshmedeski/tmux-nerd-font-window-name/main/bin/defaults.yml), ~170 programs), keeping the aliases this plugin always shipped (gvim/view, bun/npx/pnpm, ipython/ipython3) and a robot glyph for every agent herdr detects.
- `ICON_FALLBACK` (default `?`): glyph shown when a program is missing from the map, like upstream's `fallback-icon`. `''` turns the fallback off and keeps unknown programs text-only. Under `ICON_STYLE=icon` the fallback is treated as "no glyph", so an unknown program keeps its plain name (`rg`, not `?`).
- `ICON_MAP`: per-program icon overrides as `("prog=glyph")` pairs, checked before the builtin map (e.g. `ICON_MAP=("claude=󰚩")`).
- Shell labels get no icon even when the map has them: `precmd` names an idle prompt without a program, so a glyph would flip the label between `zsh` and `<glyph> zsh` on every reconcile. This covers the fixed `SHELLS` six, `IGNORED_PROGRAMS` commands showing the shell label, and the user's real login shell (`SHELL_NAME`), which can sit outside `SHELLS` (nu, tcsh, elvish, ...).

### Fixed

- `HIDE_SHELL` now blanks the login shell itself. With 0.4.0's fixed `SHELLS` six, a login shell outside the list (nu, tcsh, elvish, ...) kept naming itself on reconcile while the idle label stayed blank.
- The login shell is recognized by program rather than by computed label: `prog == SHELL_NAME` is its own shell arm, so a reconcile agrees with the bare prompt even with `SHOW_PROGRAM_ARGS=1`, where the command-line path used to hijack it.

## [0.4.0] - 2026-08-05

Adds `HIDE_SHELL`, for leaving shell tabs to herdr's own tab number instead of a row of `zsh`.

### Added

- `HIDE_SHELL=1` leaves a shell tab unnamed instead of labeling it `zsh`, so herdr renders its own tab number there and only the tabs running something carry a name (issue #5). It covers all three ways a tab gets the shell label: a bare prompt, an explicit `SHELLS` entry, and an `IGNORED_PROGRAMS` command. A `PROGRAM_ALIASES` entry for a shell still wins, being a name asked for by hand. `IGNORED_PROGRAMS` could never do this, despite reading like it should: its job is to hold a tab at the shell name, and a bare prompt short-circuits before any program list is consulted.
- With `AUTO_INDEX=1` a hidden tab keeps the jump number alone (`[3]`), and the `[N] ` prefix helpers now read that bare form back as the empty base it came from. Without that a hidden tab would see its own `[3]` as a hand-typed name and opt itself out of naming for good.

## [0.3.0] - 2026-08-04

Catches up with herdr 0.7.5 and 0.8.0. `min_herdr_version` stays at `0.7.1`: a requirement above the running herdr is a hard load failure, so every new capability is gated at runtime instead.

### Fixed

- Agent numbering has been silently failing since herdr `0.7.5`, in two ways at once, both swallowed by the `|| true` on every rename. That release stopped resolving `terminal_id` as an agent target (`resolve_agent_target` takes a current pane id or a unique agent name), and the plugin passed exactly that, since `terminal_id` is always present in `agent list`. It also added `valid_agent_name` (`^[a-z][a-z0-9_-]{0,31}$`), which rejects `[1] claude` outright. Renames now target `.pane_id`, the one form every supported herdr accepts, and agents are numbered only below `0.7.5`. At or above it the prefixes are stripped instead, which is also the only way to unstick an `[N] claude` an older herdr and older plugin left behind: that name fails every rename a newer herdr accepts, the documented uninstall `--clear` included. An unreadable herdr version counts as restricted.
- Reordering a worktree group no longer leaves stale `[N]` numbers. herdr `0.8.0` added `workspace.move_block` and routes any drag of a worktree-space member through it, which emits the new `workspace.reordered` event instead of `workspace.moved`. The plugin now subscribes to both, so a group drag renumbers immediately rather than waiting for an unrelated event.

### Added

- A `[[startup]]` hook (herdr `>= 0.7.5`) reconciles once as soon as herdr restores a session and after a live handoff. Restored sessions previously kept herdr's own labels and stale numbers until the first event happened to arrive.
- The agents herdr `0.8.0` detects are all recognized by name now, in `NAME_ONLY_PROGRAMS` and in the Nerd Font robot glyph: `pi`, `gemini`, `cursor`/`cursor-agent`, `devin`, `agy`/`antigravity`, `cline`, `omp`, `mastracode`, `opencode`, `copilot`, `kimi`, `kiro`/`kiro-cli`, `droid`, `amp`, `grok`, `hermes`, `kilo`, and `qodercli`. Two spellings differ from herdr's `--kind` id (`cursor-agent`, `kiro-cli`) and both forms are listed. Previously only `claude`, `codex`, and `aider` were, so every other agent went without an icon, and showed its whole command line under `SHOW_PROGRAM_ARGS=1`.

### Documentation

- The README records that tab naming does nothing on a Linux runtime where herdr cannot see a foreground process group, and points at herdr `0.8.0`'s opt-in `HERDR_PROCESS_DETECTION=child-groups`.
- `docs/ARCHITECTURE.md` covers the agent-name restriction and why herdr `0.7.5`'s `agent.view.set` would have made static agent numbers unreliable regardless: an active view redefines the order `focus_agent` follows, and no event or request exposes one.

## [0.2.3] - 2026-08-02

### Fixed

- A wrapped program on NixOS takes its tab name from the command that was typed rather than the wrapper underneath it, so `nh os switch` reads `nh` instead of `.nh-wrapped` ([#6](https://github.com/qu8n/herdr-automatic-rename/issues/6)). `ar_pane_program` read the foreground program from `argv0` and fell back to `name`, but herdr only sends `argv0` on some platforms; its Linux builds send `argv`, `cmdline`, and `name` alone. Those panes therefore named themselves after `name`, which is the on-disk executable rather than the invocation, and on NixOS the executable behind a wrapped program is `.<prog>-wrapped`. `argv[0]` holds what was typed and is present either way, so it now sits between `argv0` and `name`. `name` was a poor last resort regardless: a `claude` pane reports its version string there.

## [0.2.2] - 2026-07-29

### Fixed

- `ICONS_ENABLED=1` now actually prepends a Nerd Font glyph. Every arm of `ar_icon` shipped as `printf ''`, so the lookup always returned the empty string, the `[ -n "$ic" ]` guard in `ar_format` never passed, and all three `ICON_STYLE` modes did nothing. The glyphs were absent from `naming.sh` from its first commit, which means icons never worked in any release up to 0.2.1 ([#3](https://github.com/qu8n/herdr-automatic-rename/issues/3)). Each arm now carries its codepoint in a comment so a stripped glyph can be restored, and the tests assert the exact bytes rather than only checking that `ICON_STYLE=name` suppresses the glyph, which passed happily against an empty string.

## [0.2.1] - 2026-07-26

### Fixed

- Collapsing a worktree space no longer leaves stale workspace numbers behind. `alt+N` counts the sidebar's visible rows, so the members a collapsed space hides now give up their `[N]` and every row below them moves up. Collapse state is read from `collapsed_space_keys` in herdr's `session.json`, the only place herdr publishes it (no API field, no event), on herdr's 5-second save debounce.
- A space now takes its number from its main checkout instead of whichever member happens to come first in `workspace list`, matching the row herdr renders at the head of the group.
- Two linked worktrees of a repo with no main workspace open no longer group together. herdr nests a space only with 2+ members and a non-linked checkout among them, so these number as the separate top-level rows they render as.

## [0.2.0] - 2026-07-17

### Added

- Subscribe to herdr's `pane.created` event so a split that adds a pane renames the tab promptly, even when the split does not move focus.

### Changed

- A full reconcile now reads its whole picture (workspaces, tabs, panes, agents) from a single `herdr api snapshot` call instead of one query per list plus a `tab list` per workspace. Needs herdr `>= 0.7.2`; older herdr falls back to the per-list queries automatically, so the minimum supported version stays `0.7.1`.

## [0.1.1] - 2026-07-12

### Fixed

- Calling a shell function (or builtin, reserved word, or mistyped command) no longer flashes that word onto the tab before the prompt reverts it. The hooks now classify the command word; anything that is not an external command makes the engine name the tab by the pane's real foreground process, sampled after a short settle. A function that wraps a long-running program now names the tab after that program instead of the function.

## [0.1.0] - 2026-07-11

First public release.

### Added

- Tab naming (`NAME_TABS`): each tab is named after its foreground program, or the shell name at a bare prompt. A hand rename opts the tab out.
- Jump-key numbering (`AUTO_INDEX`): workspaces, tabs, and agents are prefixed with the `1-9` number of the keybind that jumps to them.
- Live per-command naming through zsh, bash, and fish shell hooks that resolve the engine relative to their own location.
- `reset` and `clear` plugin actions.
- Configuration via `~/.config/herdr-automatic-rename/config.sh` (or `$HERDR_AUTOMATIC_RENAME_CONFIG`), with a documented `config.example.sh`.
- A self-contained test suite (bash + jq only) covering naming, prefix helpers, the state machine, the shell hooks, and a full reconcile against a fake herdr.

[Unreleased]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.11.0...HEAD
[0.11.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.7.3...v0.8.0
[0.7.3]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.7.2...v0.7.3
[0.7.2]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.6.1...v0.7.0
[0.6.1]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/qu8n/herdr-automatic-rename/releases/tag/v0.1.0
