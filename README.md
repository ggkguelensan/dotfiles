# dotfiles

Agent-native, cross-platform dotfiles for **Windows + WSL2 Ubuntu + macOS**, managed by
[chezmoi](https://www.chezmoi.io/). One repo, three operating systems: each machine runs its own
independent chezmoi instance of the **same** repo, and per-OS routing in
`home/.chezmoiignore.tmpl` decides which files apply where.

The repo is designed to be opened by **Claude Code**: it carries small skills
(`.claude/skills/`) and principle docs (`docs/`) so an agent can bootstrap a machine, route a
config change to the correct layer, sync local drift back, and explain *why* the configuration
is the way it is.

## Bootstrap

Three independent chezmoi instances of the same repo — run the bootstrap **on each OS**
(Windows and WSL are two separate instances on the same physical machine).

**Windows (PowerShell):**

```powershell
winget install twpayne.chezmoi
chezmoi init --apply ggkguelensan/dotfiles
```

**WSL2 Ubuntu / Linux / macOS:**

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin && ~/.local/bin/chezmoi init --apply ggkguelensan/dotfiles
```

On first run chezmoi prompts once for the git email (default `gkguelensan@gmail.com`) and
detects WSL automatically.

**Or let an agent do it:** open this repo in Claude Code and run the
[dotfiles-setup skill](.claude/skills/dotfiles-setup/SKILL.md) — it bootstraps, applies, and verifies the machine.

## Repo map

| Path | What it is |
| --- | --- |
| `home/` | chezmoi source state (`.chezmoiroot` points here; repo root stays clean for docs/skills) |
| `home/.chezmoi.toml.tmpl` | machine config template — defines template data `.email`, `.wsl` |
| `home/.chezmoiignore.tmpl` | per-OS routing (what *not* to apply on a given OS) |
| `home/.chezmoiexternal.toml` | pulls `~/.claude/statusline.sh` from [claude-code-statusline](https://github.com/ggkguelensan/claude-code-statusline) |
| `home/.chezmoitemplates/` | shared VS Code settings/keybindings templates, included by per-OS targets |
| `home/dot_config/ghostty/config` | [Ghostty](https://ghostty.org) terminal — one XDG file serves macOS *and* Linux; cmux inherits it for rendering |
| `home/dot_config/cmux/cmux.json` | [cmux](https://github.com/manaflow-ai/cmux) app settings (macOS-only; JSONC by design) |
| `docs/principles.md` | configuration philosophies and decision vectors |
| `docs/layer-map.md` | the precedence ladder, setting scopes, and the routing table ("where does this setting go?") |
| `docs/agent-supervision.md` | attention stack, terminal topologies, persistence, node/fnm notes |
| `docs/fonts.md` | full-glyph font install per OS (MesloLGS NF links, brew casks, the "fonts install client-side" rule) |
| `.claude/skills/dotfiles-setup/` | bootstrap/verify a machine |
| `.claude/skills/dotfiles-update/` | route a config change to the right layer |
| `.claude/skills/dotfiles-sync/` | pull local drift back into the repo and commit |
| `.claude/skills/dotfiles-help/` | teach the principles behind the config |
| `CLAUDE.md` | agent working agreement for this repo |

### Per-OS routing summary

- **Windows only:** `AppData/**` (VS Code user settings/keybindings), `.wslconfig`, the
  PowerShell extension-install script.
- **macOS only:** `Library/**` (VS Code user settings/keybindings), `.config/cmux/**`.
- **WSL only:** `.vscode-server/data/Machine/settings.json` (the Remote-WSL machine layer —
  Settings Sync never touches it; this repo is its only backing store).
- **Unix only (WSL/macOS):** `.zshrc`, `.p10k.zsh`, `.tmux.conf`, `.claude/**`,
  `.config/ghostty/**`, `~/.local/bin/agent-notify`, the shell extension-install script.
  Claude Code hooks are unix-only in this repo for now, so nothing under `.claude/` is
  applied on Windows (Ghostty has no Windows build either).

## Manual post-steps

Things the repo cannot automate — the [dotfiles-setup skill](.claude/skills/dotfiles-setup/SKILL.md) walks
through verifying each:

1. **MesloLGS NF font** — install on the *host* OS (Windows/macOS) so powerlevel10k renders in
   VS Code/terminals. Direct TTF links and per-OS commands: [docs/fonts.md](docs/fonts.md).
2. **WSL clock resync scheduled task (Windows)** — the WSL2 clock drifts after host sleep and
   breaks TLS/auth for agents. Create a Scheduled Task: trigger on Event Log `System` /
   `Microsoft-Windows-Power-Troubleshooter` / Event ID 1 (resume), action
   `wsl.exe -u root -- hwclock -s`.
3. **System node symlinks in WSL** — fnm's multishell symlinks live on tmpfs and die on WSL
   restart; non-interactive processes (hooks, MCP servers, sidecars) need a durable node:
   `sudo ln -s ~/.local/share/fnm/node-versions/<LTS>/installation/bin/{node,npm,npx} /usr/local/bin/`.
4. **`/etc/wsl.conf`** — set `[interop] appendWindowsPath=false` (keeps 35 `/mnt/c` dirs out of
   `$PATH`; keep `enabled=true` for `powershell.exe`/toasts), then `wsl --shutdown`.
5. **inotify limits in WSL** — many worktrees exhaust default watch limits:
   `printf 'fs.inotify.max_user_watches=1048576\nfs.inotify.max_user_instances=512\n' | sudo tee /etc/sysctl.d/60-inotify.conf && sudo sysctl --system`.
6. **Windows toasts from WSL** — install BurntToast (`Install-Module BurntToast -Scope CurrentUser`
   in PowerShell) or drop `wsl-notify-send.exe` into the path; `agent-notify` uses whichever is
   available.
7. **Claude bell channel (WSL/VS Code machines)** — `claude config set --global
   preferredNotifChannel terminal_bell` (writes `~/.claude.json`, not chezmoi-managed). On macOS
   leave it at `auto`: Ghostty shows Claude's OSC notifications natively.
8. **macOS terminals** — `brew install --cask ghostty`; cmux:
   `brew tap manaflow-ai/cmux && brew install --cask cmux` + CLI symlink
   (`sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux`).
   Both read `~/.config/ghostty/config`; grant Ghostty Notifications permission once.

## Daily cycle

- **Edited the live config** (settings UI, tweaked `~/.zshrc`, ...): `chezmoi re-add` (or
  inspect first with `chezmoi diff`), then commit in `~/dotfiles`. The
  [dotfiles-sync skill](.claude/skills/dotfiles-sync/SKILL.md) automates this.
- **Edited the repo source** (`home/...`): `chezmoi diff`, then `chezmoi apply`.
- **New setting and unsure where it belongs:** consult `docs/layer-map.md` or run the
  [dotfiles-update skill](.claude/skills/dotfiles-update/SKILL.md).
- **Pull changes made on another machine:** `chezmoi update` (git pull + apply).

## Caveats

- **`.wslconfig` memory cap** is sized for a ~32GB host (`memory=20GB` ≈ 60%); adjust per
  machine and run `wsl --shutdown` to apply.
- **Externals respect `.chezmoiignore`**: since `.claude/**` is ignored on Windows, the
  statusline external is only fetched on unix machines. If a chezmoi version ever fetches it
  on Windows anyway, ignore the stray file — it is unused there.
- **Strict JSON**: all generated VS Code/Claude JSON files contain no comments or trailing
  commas by design; the explanations live in `docs/layer-map.md`. The single exception is
  `home/dot_config/cmux/cmux.json` — cmux documents JSONC support, so it carries comments.
- **Three instances drift independently** — run `chezmoi update` on each OS after pushing
  changes from one of them.
