---
name: dotfiles-setup
description: Bootstrap or verify a machine from this dotfiles repo — detect OS, install chezmoi, init/apply, then run the per-OS post-apply checklist with verification commands. Use when user says "set up this machine", "bootstrap", "verify my setup", "check this machine", "настрой машину", "проверь машину", "разверни дотфайлы".
---

# Setup / verify a machine

From fresh (or drifted) machine to applied + verified configuration. Theory: `docs/layer-map.md` (where things go), `docs/agent-supervision.md` (why WSL needs the extra steps).

## 1. Detect the platform

| Check | Platform |
|---|---|
| `uname -s` = `Linux` and `grep -qi microsoft /proc/version` | WSL2 |
| `uname -s` = `Darwin` | macOS |
| `$env:OS` = `Windows_NT` (PowerShell) | Windows host |

## 2. Ensure chezmoi

- Check: `command -v chezmoi` (Windows: `Get-Command chezmoi`)
- Fix — WSL/Linux: `sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin`; macOS: `brew install chezmoi`; Windows: `winget install twpayne.chezmoi`
- Verify: `chezmoi --version`

## 3. Init / apply

- Fresh machine: `chezmoi init --apply ggkguelensan` (clones github.com/ggkguelensan/dotfiles)
- Already initialized (`chezmoi source-path` succeeds): `chezmoi diff` → review → `chezmoi apply` (or `chezmoi update` to also pull)
- The statusline external (`home/.chezmoiexternal.toml`, from ggkguelensan/claude-code-statusline) downloads during apply.

## 4. Post-apply checklist (what chezmoi cannot do)

Run every row for the detected OS. Pattern per step: **check → fix → verify** (rerun the check).

### All platforms

| Step | Check | Fix |
|---|---|---|
| MesloLGS NF font installed | `fc-list \| grep -i meslo` (Linux/WSL); Font Book (macOS); Settings → Fonts (Windows) | Follow `docs/fonts.md` (direct TTF links, brew casks, per-OS commands). Remember: WSL terminals render on the WINDOWS side — install fonts there, not in the distro |
| `code` CLI on PATH | `command -v code` | macOS: "Shell Command: Install 'code' command in PATH"; Windows: reinstall VS Code with PATH option; WSL: open a folder via Remote-WSL once |
| Claude statusline renders | run `claude` and look at the bottom line; script exists at the target in `home/.chezmoiexternal.toml` (`~/.claude/statusline.sh`) | `chezmoi --refresh-externals apply`; check the script's interpreter deps (use `/usr/bin/python3`, not jq — WSL has no jq by default) |

### WSL2 (inside the distro)

| Step | Check | Fix | Verify |
|---|---|---|---|
| System node exists (fnm multishell paths are tmpfs, die on WSL restart) | `ls -l /usr/local/bin/node` | `sudo ln -s ~/.local/share/fnm/node-versions/<ver>/installation/bin/{node,npm,npx} /usr/local/bin/` (pick newest LTS in `ls ~/.local/share/fnm/node-versions`) | `/usr/local/bin/node --version` |
| vscode-server PATH pinned | `cat ~/.vscode-server/server-env-setup` contains `PATH=/usr/local/bin:$PATH` | `echo 'PATH=/usr/local/bin:$PATH' >> ~/.vscode-server/server-env-setup` | reload VS Code window; in its terminal: `which node` → `/usr/local/bin/node` |
| inotify limits for many worktrees | `sysctl -n fs.inotify.max_user_watches` ≥ 1048576 | `printf 'fs.inotify.max_user_watches=1048576\nfs.inotify.max_user_instances=512\n' \| sudo tee /etc/sysctl.d/60-inotify.conf && sudo sysctl --system` | re-check sysctl value |
| Windows PATH out of WSL | `grep -A2 '\[interop\]' /etc/wsl.conf` shows `appendWindowsPath=false` (keep `enabled=true`) | edit `/etc/wsl.conf` with sudo (NOT chezmoi-managed, root-owned). **WARN: needs `wsl --shutdown` from Windows — kills all running agents; let the user pick the moment** | after restart: `echo $PATH \| tr ':' '\n' \| grep -c /mnt/c` → 0 |
| Toast channel available | `command -v wsl-notify-send.exe` OR `powershell.exe -NoProfile -c "Get-Module -ListAvailable BurntToast"` | install wsl-notify-send.exe release into `/usr/local/bin`, or in Windows PowerShell: `Install-Module BurntToast -Scope CurrentUser` | `~/.local/bin/agent-notify "test toast"` shows a Windows toast |
| Claude bell channel (VS Code drops OSC toasts; BEL is the in-window signal) | `claude config get --global preferredNotifChannel` → `terminal_bell` | `claude config set --global preferredNotifChannel terminal_bell` (writes `~/.claude.json` — intentionally NOT chezmoi-managed) | trigger a permission prompt → terminal tab shows the bell badge + sound |

### macOS

| Step | Check | Fix | Verify |
|---|---|---|---|
| Ghostty installed | `ls /Applications/Ghostty.app` | `brew install --cask ghostty` | open Ghostty → `ghostty +list-fonts \| grep -i meslo` |
| Ghostty notifications allowed | System Settings → Notifications → Ghostty | enable Alerts (Claude Code notifies via OSC 9 natively in Ghostty — leave `preferredNotifChannel` at `auto` here) | inside Ghostty: `printf '\e]777;notify;Test;hello\a'` shows a notification |
| cmux installed | `ls /Applications/cmux.app` | `brew tap manaflow-ai/cmux && brew install --cask cmux` | launch cmux; config loads from `~/.config/cmux/cmux.json` (reload: `cmd+shift+,`) |
| cmux CLI on PATH | `command -v cmux` | `sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux` | `cmux ping` |
| gh authenticated (cmux sidebar PR status uses `gh auth token`) | `gh auth status` | `gh auth login` | PR badges appear in the cmux sidebar |
| Claude-in-cmux hooks NOT duplicated | `grep -c cmux ~/.claude/settings.json` → 0 | remove any manual cmux hooks — the bundled `claude` wrapper injects them ephemerally (see docs/agent-supervision.md §1) | notifications fire once, not twice |

### Windows host (PowerShell)

| Step | Check | Fix | Verify |
|---|---|---|---|
| Clock resync on resume (WSL clock skews after sleep → agent TLS/auth failures) | `schtasks /query /tn "WSL Clock Resync"` | Task Scheduler → Create Task "WSL Clock Resync": trigger *On an event* (Log: System, Source: Microsoft-Windows-Power-Troubleshooter, Event ID: 1); action: `wsl.exe -u root -- hwclock -s`; run whether user is logged on | after a sleep/resume cycle, `date` in WSL matches `Get-Date` |
| `.wslconfig` applied | `chezmoi diff` empty for `~/.wslconfig` | `chezmoi apply`. **WARN: takes effect only after `wsl --shutdown` — kills all agents** | inside WSL: `wslinfo --networking-mode` → mirrored; `free -h` shows the configured cap |

## 5. Final report

1. `chezmoi doctor` — must show no errors.
2. Print a table: `step | status (ok / fixed / needs-restart / skipped) | note`.
3. List separately any steps still waiting on `wsl --shutdown` — destructive, user decides when.
4. New quirk discovered? Add a row to this checklist (write-back rule in CLAUDE.md).
