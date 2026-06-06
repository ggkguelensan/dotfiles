---
name: dotfiles-update
description: Route a configuration change to the correct layer and source file, then apply it via chezmoi. Use when user says "add a setting", "change this setting", "where does this setting go", "configure X", "куда положить настройку", "добавь настройку", "поменяй настройку".
---

# Add / change a setting

`docs/layer-map.md` is **LAW**; the table below is the short form. Never edit live config files — edit source under `home/`, then apply.

## Procedure

1. **Identify the tool**: vscode / zsh / claude / tmux / git / wsl / notifications.
2. **VS Code only — determine the setting's SCOPE** (application / machine / window / resource): check `docs/layer-map.md`; if not listed there, check the VS Code docs or source. Scope decides the legal layer — machine/application values in the wrong file are silently ignored.
3. **Route to the source file** (table below).
4. Edit the source file. Generated JSON must be STRICT JSON (no comments, no trailing commas).
5. `chezmoi diff` — confirm only the intended change. Note: per-OS files only render on their own OS instance; a Windows/macOS file edited from WSL shows no local diff — it lands when that machine runs `chezmoi update`.
6. `chezmoi apply`.
7. Verify live (`chezmoi cat <target>`, reload VS Code window, open a new shell…).
8. Commit with a conventional message; push only if the user confirms.

## Routing table (short form — full version with rationale in docs/layer-map.md)

| Change | Source file (under `home/`) |
|---|---|
| VS Code setting — application- or window-scoped, personal | `.chezmoitemplates/vscode-settings.json.tmpl` (shared; renders into Windows + macOS user settings; WSL windows read the Windows user file) |
| VS Code setting — machine-scoped or WSL-perf (paths, watcher excludes) | `dot_vscode-server/data/Machine/settings.json` |
| VS Code keybinding | `.chezmoitemplates/vscode-keybindings.json.tmpl` — leader prefix is `ctrl+;` (`ctrl+,` is taken by Open Settings); keep `terminal.integrated.allowChords` at default (the leader relies on chord deferral) |
| VS Code extension | `.chezmoitemplates/vscode-extensions.txt` — `run_onchange_*` scripts install on next apply |
| zsh alias / env / PATH | `dot_zshrc` — runtime guards (`command -v`, `[ -d … ]`), not templates |
| Prompt | `dot_p10k.zsh` — ported verbatim; avoid editing |
| tmux | `dot_tmux.conf` |
| git identity / aliases | `dot_gitconfig.tmpl` |
| Ghostty (font/theme/notifications; cmux inherits it) | `dot_config/ghostty/config` — `key = value`, `#` comments on own lines only |
| cmux app behavior (macOS) | `dot_config/cmux/cmux.json` — JSONC allowed (documented exception); never `terminal.resumeCommands[]` (machine-bound HMAC) |
| Claude Code setting / hook | `private_dot_claude/settings.json.tmpl` — PUBLIC subset only, never tokens |
| Cross-OS notification logic | `dot_local/bin/executable_agent-notify.tmpl` |
| WSL VM resources / networking | `dot_wslconfig` (Windows-only file; needs `wsl --shutdown` to take effect) |
| `/etc/wsl.conf` (interop, systemd) | NOT chezmoi-managed (root-owned) — manual; see the dotfiles-setup skill |
| Project-invariant editor config (formatters, excludes per repo) | NOT this repo — the project's own `.vscode/settings.json` |

**Verified scope traps:**
- `terminal.integrated.persistentSessionScrollback` is APPLICATION-scoped → user layer only (shared template), never Machine/workspace.
- Terminal profiles (`terminal.integrated.profiles.*`, `defaultProfile.*`, `env.*`) are trust-gated window-scoped → user template or Machine file.
- `terminal.integrated.enableBell` is DEPRECATED → use `terminal.integrated.enableVisualBell` + `accessibility.signals.terminalBell`.
- `files.watcherExclude` defaults no longer include `node_modules` → exclude it explicitly (Machine file on WSL).

## Worked examples

### 1. Window-scoped VS Code setting: audible terminal bell
Goal: hear the BEL from agent terminals.
1. Setting: `accessibility.signals.terminalBell` (not the deprecated `enableBell`). Scope: user-layer personal preference.
2. Edit `home/.chezmoitemplates/vscode-settings.json.tmpl`: add `"accessibility.signals.terminalBell": { "sound": "on" }` (strict JSON).
3. `chezmoi diff` → on Windows/macOS the user `settings.json` changes; from WSL there is no local diff — commit and let the Windows instance `chezmoi update`.
4. Verify: reload VS Code window, run `printf '\a'` in a terminal → sound plays.

### 2. WSL machine setting: watcher excludes for worktrees
Goal: stop watching `node_modules` across many worktrees.
1. Scope: machine/perf, WSL-specific → Machine layer.
2. Edit `home/dot_vscode-server/data/Machine/settings.json`: add `"files.watcherExclude": { "**/node_modules/**": true, "**/dist/**": true }`.
3. `chezmoi diff && chezmoi apply` (this file belongs to the WSL instance — applies immediately).
4. Verify: reload window → "Preferences: Open Remote Settings" shows the values.

### 3. Claude Code hook: toast when an agent needs input
1. Tool: claude; hooks live in the managed public settings.
2. Edit `home/private_dot_claude/settings.json.tmpl`: under `"hooks"`, add `"Notification": [{ "hooks": [{ "type": "command", "command": "~/.local/bin/agent-notify 'needs input'" }] }]`. The notifier is the cross-OS script `dot_local/bin/executable_agent-notify.tmpl` (all args join into one message). No secrets here.
3. `chezmoi diff && chezmoi apply`.
4. Verify: `chezmoi cat ~/.claude/settings.json | /usr/bin/python3 -m json.tool` (strict-JSON check), then trigger a permission prompt and watch for the toast.
