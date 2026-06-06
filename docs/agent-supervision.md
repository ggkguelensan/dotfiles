# Agent supervision — running parallel CLI agents under VS Code + WSL2

How this repo's config makes 5–10 parallel CLI agents (Claude Code et al.) supervisable.
Each mechanism below maps to concrete files in this repo. Setting IDs verified against
VS Code 1.123 (June 2026); versions cited where gated. Companion docs:
[principles.md](principles.md) (why), [layer-map.md](layer-map.md) (where).

## 1. The attention stack

Problem: VS Code's xterm.js frontend **silently drops OSC 9 / OSC 777 desktop
notifications** (anthropics/claude-code#28338 — closed as not-planned CLI-side; still
unsupported natively as of VS Code 1.123). Claude Code's terminal-emitted notifications
work in iTerm2/Kitty/Ghostty/WezTerm but not in the integrated terminal. So attention is
layered, cheapest signal first:

1. **BEL chain (in-window).** Claude Code emits `\a` when configured:
   `claude config set --global preferredNotifChannel terminal_bell` — a **manual one-time
   step per machine** (`claude config` writes `~/.claude.json`, which this repo does not
   manage; the dotfiles-setup checklist includes it). Recommended on WSL/VS Code machines;
   on macOS leave the channel at `auto` so Ghostty's native notifications fire instead.
   VS Code surfaces BEL from *unfocused* terminals via:
   - `terminal.integrated.enableVisualBell: true` — bell icon on the terminal tab for
     `terminal.integrated.bellDuration` ms. (`terminal.integrated.enableBell` is
     **deprecated** since v1.87 — never use it.)
   - `accessibility.signals.terminalBell: {"sound": "on"}` — audible bell; the namespace
     replaced `audioCues.*` in v1.87. BEL travels from the WSL PTY to the Windows renderer;
     the sound plays on Windows with no interop needed.
   Both live in the user settings template (`home/.chezmoitemplates/vscode-settings.json.tmpl`).
2. **OS toasts (out-of-window).** Claude Code `Notification` (awaiting input/permission)
   and `Stop` (response finished) hooks call `~/.local/bin/agent-notify`
   (`home/dot_local/bin/executable_agent-notify.tmpl`), which branches per OS at runtime:
   WSL → Windows toast via `powershell.exe` BurntToast or `wsl-notify-send.exe`
   (~100 ms vs ~1–2 s PowerShell cold start); macOS → `osascript`; Linux → `notify-send`.
   This works regardless of window focus, topology, or which terminal hosts the agent —
   treat toasts as the source of truth, in-window signals as garnish.
3. **Title-driven (passive).** Claude Code rewrites its terminal title continuously;
   with the tab templating below, every tab is a live status line. Highest-signal
   zero-cost indicator.
4. **Optional bridge extension.** `wenbopan.vscode-terminal-osc-notifier` parses OSC 9/777
   from integrated terminals and raises OS toasts — useful for agents whose hooks you
   don't control.
5. **VS Code-native (chat-scoped only).** `chat.notifyWindowOnConfirmation` (v1.102+)
   badges the dock/taskbar when *VS Code's own* chat agent needs confirmation. It does NOT
   cover CLIs in terminals — don't rely on it for terminal agents.

Known hole: there is no built-in "this terminal printed new output while unfocused" badge
for plain terminals (as of 1.123). Hooks + bell are the workaround.

**macOS exception — no workarounds needed.** Ghostty supports OSC 9/777 natively
(`desktop-notifications = true` by default) and Claude Code detects
`TERM_PROGRAM=ghostty` and notifies on its own; the repo config
(`home/dot_config/ghostty/config`) also adds OSC 9;4 progress bars and
`notify-on-command-finish = unfocused`. cmux (manaflow-ai) inherits that same
ghostty config for rendering, adds OSC 99 + a notification feed/sidebar, and its
Claude Code integration is **zero-config**: the bundled `claude` wrapper injects
hooks ephemerally via `claude --settings` when run inside cmux — do **NOT** wire
cmux into `~/.claude/settings.json` hooks (it would double-fire with
`agent-notify`; opt-out env: `CMUX_CLAUDE_HOOKS_DISABLED=1`). cmux app settings:
`home/dot_config/cmux/cmux.json`.

## 2. Tab identification

Default `${process}` renders eight tabs all named "zsh". In the user settings template:

```
"terminal.integrated.tabs.title": "${sequence}",
"terminal.integrated.tabs.description": "${cwdFolder}${separator}${task}",
"terminal.integrated.tabs.location": "left",
"terminal.integrated.tabs.hideCondition": "never"
```

`${sequence}` = the title the running app set via escape sequence — Claude Code actively
sets it, so each tab becomes a live agent status readout. `${cwdFolder}` uniquely names
each agent's worktree under worktree-per-agent. Per-profile `icon`/`color` (in
`terminal.integrated.profiles.linux`, remote Machine file) makes agent terminals visually
distinct from plain shells. Other variables exist (`${progress}` for OSC 9;4, v1.97+;
`${shellCommand}`/`${shellPromptInput}`, v1.96+, unreliable under powerlevel10k).

## 3. Persistence model — reconnect vs revive

Two different machines hide behind `terminal.integrated.enablePersistentSessions`:

- **Reconnect**: the PTY host (inside vscode-server on WSL) keeps the process running;
  the window reattaches. The agent TUI genuinely survives, buffer intact.
- **Revive** (`terminal.integrated.persistentSessionReviveProcess`): only scrollback TEXT
  is restored (capped by `persistentSessionScrollback`, default a measly 100 lines,
  application-scoped → user settings file only) and a FRESH shell is launched. The agent
  process is dead.

| Event | Outcome for a running agent |
|---|---|
| Reload Window | **Safe** — reconnect, agent keeps running |
| Extension install / window-side flakiness | Safe — reconnect |
| Close the VS Code window (WSL) | **Usually survives** — vscode-server often keeps running in the VM, but this is NOT contractual |
| `wsl --shutdown` / distro restart / Windows reboot | **Dead** — revive only: frozen scrollback + fresh shell → `claude --resume` / `claude --continue` |
| VS Code self-update (server replaced with new commit) | **Dead** — same as above; this happens on every update |
| WSL VM OOM | Dead — the OOM killer favors big node processes (often an agent) |

Config (user template): `persistentSessionReviveProcess: "onExitAndWindowClose"`,
`persistentSessionScrollback: 5000`, `scrollback: 10000`, `confirmOnKill: "always"`.

**The tmux hedge.** For agents that must survive everything short of VM death, the remote
Machine settings (`home/dot_vscode-server/data/Machine/settings.json`) define an
`agent-tmux` terminal profile that runs `tmux new-session -A -s <name>` (idempotent
attach-or-create). tmux sessions survive window reload, window close, VS Code updates and
vscode-server crashes; only `wsl --shutdown`/OOM end them. `home/dot_tmux.conf` sets a
large `history-limit` and `allow-passthrough on` (so OSC sequences and shell integration
still flow through tmux). Note: there is no "Remote-WSL: Kill VS Code Server" command (it
never existed — Remote-SSH only); to restart the server, `wsl --shutdown` + reload.

## 4. Topologies

Hard numbers first: every Remote-WSL **window** spawns its own remote extension host
(~660 MB measured) + file watcher (~64 MB) + language-server children inside WSL —
**≈0.5–1.5 GB of WSL RAM per window** before any agent runs (one full window stack
measured at ~1.35 GB RSS). Terminals are cheap (one shared ptyHost, ~95 MB); windows are
expensive. Practitioner consensus: ~3–5 parallel agents before coordination overhead
dominates anyway.

- **Topology A — one window, agent terminals in the editor area (default).** Single
  Remote-WSL window on the main checkout; each agent in `claude --worktree <task>` (or
  `claude --bg`); terminals as editor tabs (`terminal.integrated.defaultLocation:
  "editor"`), auto-locked groups (`workbench.editor.autoLockGroups` already defaults
  `terminalEditor: true`) so file opens never steal an agent tile. One terminal running
  `claude agents` (CLI ≥2.1.139) as the supervision hub. Cheapest RAM, zero
  window-switching.
- **Topology B — window-per-worktree.** Strongest isolation + glanceable identity for 2–3
  long-lived streams. Label windows via the user template:
  `"window.title": "${rootNameShort} ⊢ ${activeRepositoryBranchName}${separator}${activeEditorShort}${separator}${remoteName}"`
  (all variables verified in 1.123). Costs linear extension-host RAM; hard ceiling ~4–5
  windows on a 16–32 GB host. Pair with OS toasts (hooks), since per-window signals
  fragment. Bind `workbench.action.switchWindow` (unbound by default) in the keybindings
  template; set `files.hotExit: "onExitAndWindowClose"`.
- **Topology C — multi-root workspace of worktrees.** Max RAM savings, one window, all
  worktrees searchable; but only resource-scoped settings apply per-folder, window
  identity can't distinguish agents, and VS Code's Agents tooling lacks multi-root support
  (vscode#311148, open). Use as a review/compare window, not the daily driver.

## 5. The node/fnm root cause (and the fix the dotfiles-setup skill applies)

Root cause of "fnm is unstable" on the WSL box: **no system Node exists** —
`node` resolves only to `/run/user/<uid>/fnm_multishells/<pid>_<ts>/bin/node`, a per-shell
symlink on tmpfs, wiped on WSL restart. The remote extension host snapshots its
environment ONCE at server start, capturing one such path that later dies. Every
non-interactive spawn (extension child processes, Claude Code hooks running `sh -c`,
npx-based MCP servers) then gets `node: command not found` or a dead symlink.

Fix (two parts, applied by the `dotfiles-setup` skill, documented here for the why):

1. **Durable system node**: symlink an fnm-installed version into a stable path —
   `sudo ln -s ~/.local/share/fnm/node-versions/<ver>/installation/bin/{node,npm,npx} /usr/local/bin/`
   — or install a NodeSource LTS. Keep fnm for interactive per-project switching only.
2. **Pin the server PATH**: `~/.vscode-server/server-env-setup` (Bourne shell, runs before
   vscode-server starts) with `PATH=/usr/local/bin:$PATH`, so the extension host, hooks
   and MCP servers always resolve the durable node.

Related shell hygiene in `home/dot_zshrc`: fnm is initialized exactly once with a runtime
guard (`command -v fnm`), no duplicate `eval "$(fnm env)"` blocks, single cached
`compinit` — agent workflows spawn shells constantly, so startup time is a recurring tax.

## 6. WSL clock skew

The WSL2 VM clock pauses across host sleep/hibernate; on resume Linux time can lag
minutes-to-hours (microsoft/WSL#13867, still open for Ubuntu 24.04). Symptoms hit all
agents at once: TLS "certificate not yet valid" on api.anthropic.com, OAuth/JWT skew
rejections, git timestamps in the past. `systemd-timesyncd` self-heals small drift but is
slow to step large offsets.

Fix (documented in the `dotfiles-setup` skill; lives on the Windows side, not in chezmoi): a
Windows Scheduled Task triggered on Event Log `Microsoft-Windows-Power-Troubleshooter`
Event ID 1 (resume) running `wsl.exe -u root -- hwclock -s`. Manual fallback when agents
suddenly throw cert errors: `sudo hwclock -s`. Anti-pattern: cron'd `hwclock -s` every
minute (steps time backwards mid-build).

## 7. Ports under mirrored networking

`home/dot_wslconfig` sets `networkingMode=mirrored` (requires Win11 22H2+): bidirectional
`127.0.0.1` between Windows and Linux, so VS Code port forwarding becomes a UX layer
(labels, open-in-browser), not plumbing. Consequences for parallel agents:

- **One shared port namespace** across Linux AND Windows: two agents binding the same port
  is a hard conflict (no NAT isolation). Assign each agent a deterministic port range.
- **Windows excluded port ranges** (Hyper-V reserves random blocks) can mysteriously block
  agent dev-server binds — check with
  `netsh int ipv4 show excludedportrange protocol=tcp`.
- **Notification spam control** (remote Machine or workspace layer):
  `remote.portsAttributes` mapping agent ranges to `{"onAutoForward": "silent"}` and
  inspector ports to `"ignore"`; `remote.otherPortsAttributes: {"onAutoForward": "silent"}`.
- The 20-port fallback: with `remote.autoForwardPortsSource: "process"`, exceeding 20
  forwarded ports silently switches detection to hybrid (`remote.autoForwardPortsFallback`,
  ~v1.85+); 5–10 agents with dev server + HMR + inspector each can plausibly hit it —
  user settings carry `"remote.autoForwardPortsSource": "hybrid"` up front.

## 8. Resource governance (the .wslconfig contract)

`home/dot_wslconfig` (Windows-side file; changes require `wsl --shutdown` — which kills
all agents, so apply between sessions): explicit `memory=` cap sized to leave the Windows
UI + browser headroom, `swap=` raised so the Linux OOM killer doesn't snipe an agent or
the extension host under burst, `[experimental] autoMemoryReclaim=gradual` (idle agents'
page cache returns to Windows; fall back to `dropcache` if terminals hang),
`sparseVhd=true` (worktree churn creates/deletes GBs of `node_modules` — without it the
VHDX only grows). On the VS Code side: `files.watcherExclude` must explicitly include
`**/node_modules/**` — the shipped defaults **no longer exclude node_modules at all**
(verified 1.123) — plus build dirs and the worktree pool; raise inotify limits
(`fs.inotify.max_user_watches`, `max_user_instances`) via sysctl when running many
worktrees (dotfiles-setup skill).
