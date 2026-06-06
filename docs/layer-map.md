# Layer map — the routing table

**This is the authoritative answer to "where does setting X go?"** The `dotfiles-update` skill
follows this document. Verified against VS Code 1.123 (June 2026).

## 1. The precedence ladder

Later wins. Official order (settings docs):

1. Default settings
2. **User** settings (per OS, per profile)
3. **Remote machine** settings (WSL/SSH only: `~/.vscode-server/data/Machine/settings.json`)
4. **Workspace** settings (`.vscode/settings.json` or `.code-workspace` `settings{}`)
5. **Workspace folder** settings (multi-root only)
6.–10. Language-specific (`"[typescript]": {}`) repeats of layers 1–5
11. Policy settings (enterprise; always override)

Gotcha worth remembering: any language-specific *user* setting beats a plain *workspace*
setting for that language (the language ladder sits on top of the plain ladder).

Under Remote-WSL the "user" layer is the **Windows-side** `%APPDATA%\Code\User\settings.json`;
the remote Machine file overrides it but loses to workspace settings:
Windows user < WSL Machine < workspace < folder.

## 2. The six scopes

Each setting declares one scope (in the extension's/core's `contributes.configuration`).
Scope limits which ladder layers may legally set it:

| Scope | May be set in | Example |
|---|---|---|
| `application` | User settings file ONLY (the local one; never remote, never workspace) | `update.mode`, `terminal.integrated.persistentSessionScrollback`, `terminal.integrated.inheritEnv` |
| `machine` | User or remote-Machine settings; never workspace | `git.path` |
| `machine-overridable` | Like `machine`, but workspace/folder MAY override | `python.defaultInterpreterPath` |
| `window` (default) | User, remote, or workspace | `window.title`, `terminal.integrated.tabs.title` |
| `resource` | All layers incl. per-folder in multi-root | `files.exclude`, `editor.formatOnSave` |
| `language-overridable` | `resource` + inside `[language]` blocks | `editor.defaultFormatter` |

**THE RULE: machine- and application-scoped settings written into workspace files
(`.vscode/settings.json`, `.code-workspace`) are SILENTLY IGNORED.** The Settings editor
grays them out; JSON edits just don't apply. This is the #1 mis-routing failure mode.

Orthogonal axis — **trust-gating**: settings declared `restricted: true` (terminal
profiles, `terminal.integrated.defaultProfile.*`, `automationProfile.*`,
`terminal.integrated.env.*` — anything naming an executable) are mostly *window*-scoped
and CAN be set in workspace files, but apply only in **trusted** folders. In Restricted
Mode VS Code falls back to the user value.

Sync axis: machine-scoped settings never sync (by design); Settings Sync never touches
remote Machine files at all. That blind spot is a core reason this repo exists
(see [principles.md](principles.md) §3).

## 3. The routing table

| Layer | Physical file (per OS) | File in THIS repo | What belongs there |
|---|---|---|---|
| **VS Code user settings** (Windows) | `%APPDATA%\Code\User\settings.json` | `home/AppData/Roaming/Code/User/settings.json.tmpl` → stub invoking shared template `home/.chezmoitemplates/vscode-settings.json.tmpl` | Application-scoped settings (they can live nowhere else): `terminal.integrated.persistentSessionScrollback`, `terminal.integrated.inheritEnv`; theme/fonts/UI; `window.title`; bell/attention signals; keystroke-routing settings; anything cross-machine personal |
| **VS Code user settings** (macOS) | `~/Library/Application Support/Code/User/settings.json` | `home/Library/Application Support/Code/User/settings.json.tmpl` → same shared template | Same as above (per-OS divergence handled inside the template via `{{ if eq .chezmoi.os "darwin" }}`) |
| **VS Code user settings** (Linux native, non-WSL) | `~/.config/Code/User/settings.json` | **NOT in this repo** — the Linux machine here is WSL, which renders through the Windows client. If a native-Linux desktop ever appears, add `home/dot_config/Code/User/{settings,keybindings}.json.tmpl` stubs invoking the shared templates | n/a |
| **VS Code WSL remote machine** | `~/.vscode-server/data/Machine/settings.json` (inside the distro) | `home/dot_vscode-server/data/Machine/settings.json` | Machine-scoped values for WSL windows + remote baselines: `terminal.integrated.profiles.linux` (incl. the `agent-tmux` profile), `files.watcherExclude` additions, `remote.portsAttributes`. NOT application-scoped settings (ignored here). Settings Sync never sees this file — only chezmoi protects it |
| **VS Code keybindings** | Windows `%APPDATA%\Code\User\keybindings.json`; macOS `~/Library/Application Support/Code/User/keybindings.json` | `home/.chezmoitemplates/vscode-keybindings.json.tmpl` via the per-OS stubs next to settings | ALL keybindings, including ones used in WSL windows. **Keybindings resolve CLIENT-side** — there is no remote keybindings file; that is exactly why this repo applies them per-OS. Leader prefix is `ctrl+;` (`ctrl+,` is taken by Open Settings — do not use it) |
| **VS Code extensions manifest** | n/a (installed state) | `home/.chezmoitemplates/vscode-extensions.txt` + `home/run_onchange_install-vscode-extensions.{sh,ps1}.tmpl` | Desired extension list; the run_onchange scripts install on apply. Note: WSL-side (workspace-kind) extensions install per-distro and don't sync — the unix script covers them |
| **Claude Code user config** | `~/.claude/settings.json` | `home/private_dot_claude/settings.json.tmpl` (mode 0600) | Hooks (Notification/Stop → `agent-notify`), statusline wiring, permissions, model defaults. NOT `preferredNotifChannel` — that lives in `~/.claude.json` via `claude config set --global` (manual; in the dotfiles-setup checklist). Per-machine secrets stay OUT (use env or local overrides) |
| **Cross-OS notifier** | `~/.local/bin/agent-notify` | `home/dot_local/bin/executable_agent-notify.tmpl` (+x) | The one script all agent hooks call; OS branching inside (WSL → Windows toast, macOS → `osascript`, Linux → `notify-send`) |
| **Shell** | `~/.zshrc`, `~/.p10k.zsh` | `home/dot_zshrc`, `home/dot_p10k.zsh` | Shell init. Prefer RUNTIME guards (`command -v fnm`, `[ -d ... ]`) over chezmoi templating — template only true per-OS divergence |
| **tmux** | `~/.tmux.conf` | `home/dot_tmux.conf` | `history-limit`, `allow-passthrough on` (needed for OSC/shell-integration passthrough under VS Code) |
| **git** | `~/.gitconfig` | `home/dot_gitconfig.tmpl` | Identity (templated from `.email`), aliases, per-OS credential helper |
| **Ghostty terminal** (macOS + Linux; no Windows build) | `~/.config/ghostty/config` (XDG path works on macOS too; keep the Application Support variant empty — it would override) | `home/dot_config/ghostty/config` | Font/theme/scrollback, shell integration, OSC 9/777 notifications, bell-features, quick terminal, macOS option-as-alt. `key = value` format, `#` comments on own lines only. **cmux inherits this file** for rendering |
| **cmux app settings** (macOS only) | `~/.config/cmux/cmux.json` | `home/dot_config/cmux/cmux.json` | App behavior: telemetry opt-out, agent integrations, notifications, sidebar, socket API mode. **JSONC by design** (documented exception to the strict-JSON rule). NOT `terminal.resumeCommands[]` (HMAC-signed, machine-bound) and NOT session state (`~/Library/Application Support/cmux/`, `~/.cmuxterm/`) |
| **WSL VM config** | `%UserProfile%\.wslconfig` — **a Windows-side file** that governs the whole WSL2 VM | `home/dot_wslconfig` (applied only on Windows via `.chezmoiignore.tmpl`) | `networkingMode=mirrored`, `memory=`, `swap=`, `[experimental] autoMemoryReclaim=gradual`, `sparseVhd=true`. Changes need `wsl --shutdown` (kills agents — do between sessions) |
| **WSL distro config** | `/etc/wsl.conf` (root-owned, inside the distro) | **NOT in this repo** — manual; the `dotfiles-setup` skill documents the desired content (`[boot] systemd=true`, `[interop] appendWindowsPath=false`) | chezmoi manages `$HOME`, not `/etc`. Apply by hand with sudo, verify via the dotfiles-setup skill |
| **Project `.vscode/`** (settings/tasks/launch/extensions.json) | `<repo>/.vscode/` | **NOT in this repo** — belongs to each project's own git repo | Resource-scoped, project-invariant, path-free settings only (formatters, excludes, tasks). Machine/application-scoped entries there are dead weight (silently ignored) |

Statusline: `~/.claude/statusline.sh` is pulled from the separate repo
`github.com/ggkguelensan/claude-code-statusline` via `home/.chezmoiexternal.toml` —
do not vendor or edit it here.

## 4. Decision procedure — "where does setting X go?"

Run these checks in order. The `dotfiles-update` skill automates this.

**Step 1 — Is it a VS Code setting? Check its scope.**
Find the scope in the Settings editor (gear → "Copy Setting ID", or hover shows
sync/remote hints) or in `contributes.configuration` of the owning extension.
- `application` → user settings template (`vscode-settings.json.tmpl`). It will NOT work
  in the WSL Machine file or any workspace file.
- `machine` / `machine-overridable` → for WSL behavior: `home/dot_vscode-server/data/Machine/settings.json`.
  For local-only OSes: user settings template.
- `window` / `resource` → either layer works; prefer the user template for personal
  preferences, the WSL Machine file for WSL-only baselines, the project's `.vscode/` for
  project-invariant values (which means: not this repo).
- `restricted: true`? It applies only in trusted workspaces — note that in the rationale.

**Step 2 — Which OS(es)?**
- All OSes, same value → straight into the shared template.
- Per-OS divergence → branch inside the template: `{{ if eq .chezmoi.os "windows" }}` /
  `"darwin"` / `"linux"`; WSL-specific: `{{ if .wsl }}`. Only `.email`, `.wsl`, and
  chezmoi built-ins are available as template data.
- Windows-host file governing WSL (`.wslconfig`) → `home/dot_wslconfig`, Windows apply only.
- Not a VS Code setting at all → route by tool: shell → `dot_zshrc` (runtime-guarded),
  tmux → `dot_tmux.conf`, git → `dot_gitconfig.tmpl`, Claude Code →
  `private_dot_claude/settings.json.tmpl`, notifier behavior → `agent-notify`.

**Step 3 — Personal vs project.**
- Would every collaborator on a given repo want it, machine-independently? → project's
  `.vscode/` in THAT repo. Not here.
- Personal, follows the human across machines? → this repo, per steps 1–2.
- Per-machine secret or one-off experiment? → local overrides
  (`.claude/settings.local.json`, env vars), never committed.

**Step 4 — Write it down.** Add the setting with strict JSON, and if it is non-obvious or
version-gated, record the rationale + VS Code version in this file's companion notes or
the commit message. Then `chezmoi apply` (or `chezmoi diff` first) and verify in a fresh
window/shell.

### Common mis-routings (learned the hard way)

| Mistake | Why it fails | Correct route |
|---|---|---|
| `persistentSessionScrollback` in the WSL Machine file | application-scoped → ignored outside user settings | user settings template |
| Terminal profiles in Windows user settings, expecting them in WSL windows | WSL windows read profiles from the REMOTE tier | `dot_vscode-server/data/Machine/settings.json` |
| Keybindings "for WSL" placed anywhere remote | keybindings resolve client-side only | OS-local keybindings stub (e.g. Windows file even for WSL work) |
| `git.path` in a project's `.vscode/settings.json` | machine-scoped → silently ignored | user or Machine settings |
| Relying on Settings Sync to back up the Machine file | Sync never operates on remote connections | this repo |
| `terminal.integrated.allowChords: false` to "fix" chords | breaks the `ctrl+;` leader (it depends on chord deferral from terminals) | keep the default `true` |
