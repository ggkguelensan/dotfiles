# Configuration principles

Why this repo is shaped the way it is. Read this before changing any config; the
[layer-map](layer-map.md) tells you *where* a change goes, this doc tells you *why*.
Setting IDs are exact and verified against VS Code 1.123 (June 2026) unless version-gated otherwise.

## The 5 philosophies

### 1. Layered model + scopes (the platform's rules, not ours)

VS Code resolves settings through a strict precedence ladder — defaults → user →
remote machine → workspace → workspace-folder, with language-specific (`"[typescript]": {}`)
repeats of that ladder on top, and enterprise policy overriding everything. "Later wins",
**but** every setting declares a *scope* that limits which layers may legally set it:
`application`, `machine`, `machine-overridable`, `window` (default), `resource`,
`language-overridable`. Machine- and application-scoped settings written into a repo's
`.vscode/settings.json` are **silently ignored**. Concrete examples that bite:
`terminal.integrated.persistentSessionScrollback` and `terminal.integrated.inheritEnv` are
application-scoped (user settings file only — never workspace, never remote Machine);
`git.path` is machine-scoped; terminal profiles (`terminal.integrated.profiles.*`,
`defaultProfile.*`, `env.*`) are window-scoped but *trust-gated* — settable in workspace
files yet honored only in trusted folders. We don't fight this model; the routing table in
`layer-map.md` encodes it.

### 2. Minimal defaults over heavy customization

VS Code's defaults are deliberately well-tuned and every override is maintenance debt that
must survive updates (VS Code released ~weekly in spring 2026 — version-gating is real).
Rule: an override enters this repo only if it (a) fixes a measured problem (e.g. default
`terminal.integrated.scrollback` of 1000 truncates agent transcripts), (b) enables a
workflow the default forbids (BEL-based attention signals are off by default), or
(c) corrects a default that is wrong for the agent-supervision workflow
(`terminal.integrated.minimumContrastRatio` 4.5 rewrites TUI colors). Pure taste stays out
or is documented as taste. Every non-obvious override gets a rationale in
`docs/layer-map.md` — **never** as a comment inside generated JSON (all generated JSON in
this repo is strict: no comments, no trailing commas).

### 3. Configuration-as-code — why this repo exists

Settings Sync handles the Windows/macOS *user* layer well, but it is scope-aware **by
design**: machine-scoped settings never sync, and Sync does not operate inside remote
connections at all. That means `~/.vscode-server/data/Machine/settings.json` — the WSL
remote-machine layer, the only place machine-scoped settings apply in WSL windows — is a
**Settings Sync blind spot**: it is wiped whenever `~/.vscode-server` is deleted (a
standard WSL troubleshooting step) and nothing restores it. Same story for `~/.zshrc`,
`~/.tmux.conf`, `~/.wslconfig`, `~/.claude/settings.json`: no platform syncs them. chezmoi
gives all of these git history, code review, per-OS templating (`.chezmoi.os`, `.wsl`),
and one-command machine bootstrap. The repo is the source of truth; live files are derived
state. Drift flows back via the `dotfiles-sync` skill, never by hand-editing both sides.

### 4. Profile-per-activity

VS Code Profiles (GA since 1.75) bundle settings + keybindings + extensions + UI state +
MCP servers per activity, with partial inheritance from the Default profile. They are the
sanctioned way to keep a heavyweight agent-supervision layout (many terminals, locked
groups, supervision extensions) from polluting everyday editing. Two hard limits shape our
usage: profiles do **not** export machine-scoped settings, and they do **not** sync
extensions into remote (WSL) contexts — so profiles complement this repo, they don't
replace it. This repo carries the cross-profile baseline; profiles layer activity-specific
deltas on top.

### 5. Workspace Trust is an orthogonal axis

Trust is a second gate, independent of scope. Restricted Mode disables AI agents,
terminal opening, task execution, debugging, and all `restricted: true` settings (anything
naming an executable: terminal profiles, `terminal.integrated.env.*`, automation
profiles). `runOn: "folderOpen"` tasks never run untrusted, and since 1.109
`task.allowAutomaticTasks` defaults to `"off"` even in trusted folders. Trusting a parent
folder trusts all subfolders — so a worktree-per-agent workflow needs its worktree pool
under one pre-trusted parent, or every spawned window starts dead. Keep
`security.workspace.trust.enabled: true`; pre-trust deliberately, never disable trust
globally.

## Configuration vectors for parallel-CLI-agent work

The settings that matter when supervising 5–10 CLI agents (Claude Code et al.) in
terminals, grouped by the problem they solve. Details and the full attention stack live in
[agent-supervision.md](agent-supervision.md).

| Vector | Problem | Key setting IDs |
|---|---|---|
| **Terminal identification** | 8 tabs all named "zsh" | `terminal.integrated.tabs.title: "${sequence}"` (Claude Code live-updates the title), `tabs.description: "${cwdFolder}${separator}${task}"`, `tabs.location: "left"`, `tabs.hideCondition: "never"`; per-profile `icon`/`color` in `terminal.integrated.profiles.linux` |
| **Attention** | Knowing an unfocused agent needs input | `terminal.integrated.enableVisualBell` + `accessibility.signals.terminalBell` (NOT the deprecated `terminal.integrated.enableBell`), `terminal.integrated.bellDuration`, `chat.notifyWindowOnConfirmation` (v1.102+); Claude Code `preferredNotifChannel: terminal_bell` + Notification/Stop hooks → `agent-notify` |
| **Persistence** | Agents surviving reloads/restarts | `terminal.integrated.enablePersistentSessions`, `persistentSessionReviveProcess: "onExitAndWindowClose"`, `persistentSessionScrollback` (application-scoped → user layer only), `scrollback: 10000`, `confirmOnKill: "always"`; tmux `agent-tmux` profile as the real guarantee |
| **Keyboard routing** | Workbench eats TUI keys; leader chords must work in terminals | `terminal.integrated.commandsToSkipShell` (`-` prefix removes a default), `terminal.integrated.allowChords` **left at default `true`** — the `ctrl+;` leader relies on chord deferral from focused terminals; `sendKeybindingsToShell` stays `false` |
| **Layout** | Terminals as first-class tiles | `terminal.integrated.defaultLocation: "editor"`, `workbench.editor.autoLockGroups: {"terminalEditor": true}` (default), `workbench.editor.revealIfOpen`, `workbench.activityBar.location`, panel position commands |
| **Windows** | Telling worktree windows apart | `window.title` with `${rootNameShort}`/`${activeRepositoryBranchName}`/`${remoteName}` (verified in 1.123), `window.restoreWindows`, `workbench.action.switchWindow` (unbound by default — bind it), `files.hotExit: "onExitAndWindowClose"` |
| **Tasks** | Launching a labeled agent fleet | compound `dependsOn` tasks, `presentation.panel: "dedicated"` + `presentation.group`, `icon: {id, color}`, `runOptions.runOn: "folderOpen"` + `task.allowAutomaticTasks` (trust-gated) |
| **WSL resources** | N windows × N watchers × N node processes | `.wslconfig`: `memory=`, `swap=`, `autoMemoryReclaim=gradual`, `sparseVhd=true`; `files.watcherExclude` (defaults no longer exclude `node_modules` — add `**/node_modules/**` yourself), inotify sysctls, `git.autoRepositoryDetection` |
| **Notifications (OS-level)** | Toasts when the window is unfocused | VS Code drops OSC 9/777 (claude-code#28338) → `agent-notify` script (BurntToast/`wsl-notify-send` on WSL, `osascript` on macOS, `notify-send` on Linux) wired into Claude Code hooks; optional `wenbopan.vscode-terminal-osc-notifier` extension |

## Operating rules derived from the above

1. **Route before you write.** Every config change goes through the decision procedure in
   `layer-map.md` (scope → OS → personal-vs-project). Wrong-layer settings are silently
   ignored, which is worse than an error.
2. **The repo is upstream.** Edit chezmoi source state, `chezmoi apply`, verify. If you
   edited a live file in anger, pull the change back with the `dotfiles-sync` skill the same day.
3. **Version-gate your claims.** When adding a setting that appeared after ~2024, note the
   VS Code version in `layer-map.md`. Cadence is ~weekly in 2026; "current" rots fast.
4. **Strict JSON in generated files.** Explanations live in docs, not in output files.
5. **Project config stays in projects.** Repo-level `.vscode/` (resource-scoped settings,
   tasks, extension recommendations) belongs to each project's own repo, never here.
