# dotfiles — agent working agreement

> **One-line goal:** ONE cross-platform configuration monorepo (Windows / WSL2 Ubuntu / macOS), managed by [chezmoi](https://www.chezmoi.io/), built to be opened by Claude Code on any machine: it carries the skills and principle docs an agent needs to set up a machine, route a config change to the correct layer, and explain WHY.

Three machines run three **independent instances** of this repo — one per OS. There is no "main machine": each clone applies the same source state, and per-OS routing (`home/.chezmoiignore.tmpl`, `{{ .chezmoi.os }}`, `{{ .wsl }}`) decides which slice lands on which machine. A change to a Windows-only file edited from WSL takes effect only when the Windows instance pulls and applies.

## Read before working

1. **`docs/layer-map.md`** — the precedence ladder, setting scopes, and the ROUTING TABLE. This is **LAW** for deciding where a config change goes. Never guess a layer.
2. **`docs/principles.md`** — the configuration philosophies behind the routing (what's worth managing, runtime guards vs templates, config-as-code vs Settings Sync).
3. **`docs/agent-supervision.md`** — attention stack, window topologies, terminal persistence, node/fnm — for anything touching agent workflows.

## chezmoi crash course (for agents)

- **Source state** lives in `home/` (`.chezmoiroot` contains `home`); the repo root stays clean for docs and skills.
- `chezmoi diff` — preview what `apply` would change. ALWAYS run before apply.
- `chezmoi apply` — write source state to the live home directory.
- `chezmoi re-add <file>` — pull live drift (a file edited outside the repo) back into source. Refuses templates — port those by hand.
- `chezmoi cat <target>` — render one file (e.g. `chezmoi cat ~/.zshrc`) to check template output without applying.
- `chezmoi doctor` — sanity-check the install.
- `chezmoi update` — git pull the repo + apply (how other machines pick up pushed changes).
- **NEVER edit live config files directly** (`~/.zshrc`, VS Code `settings.json`, …). Edit the source file under `home/`, preview with `chezmoi diff`, then `chezmoi apply`.
- Source naming: `dot_` → leading dot; `private_` → mode 0600; `executable_` → +x; `.tmpl` → Go template.
- Template data: `.email` (string), `.wsl` (bool) — defined in `home/.chezmoi.toml.tmpl` — plus built-ins like `.chezmoi.os`. Use ONLY these.

## Conventions

- Generated JSON files are **STRICT JSON** — no comments, no trailing commas. Explanations live in `docs/layer-map.md`, never inline. Single exception: `home/dot_config/cmux/cmux.json` is JSONC by design (cmux documents comment support).
- Shell files prefer **runtime guards** (`command -v x`, `[ -d … ]`) over chezmoi templating; template only for true per-OS divergence.
- Shared VS Code templates are invoked as `{{- template "vscode-settings.json.tmpl" . -}}` from the per-OS stub files.
- Engineering docs are written in **English**; chat with the maintainer is in **Russian**.

## Write back durable knowledge

- Config change → correct source file per `docs/layer-map.md` → `chezmoi diff` → `chezmoi apply` → verify live → commit (conventional message, e.g. `feat(vscode): raise terminal scrollback`).
- New principle, routing fact, or supervision finding → append to the right doc under `docs/`.
- New machine quirk discovered during bootstrap → extend the checklist in `.claude/skills/dotfiles-setup/SKILL.md`.

## Safety

- **Never commit secrets or tokens.** Review every diff before committing; the dotfiles-sync skill greps for token patterns.
- `home/private_dot_claude/settings.json.tmpl` (→ `~/.claude/settings.json`) is the **PUBLIC subset** of Claude Code settings. Secrets and machine-local experiments stay in `~/.claude/settings.local.json`, which this repo does not manage.
- Don't `chezmoi apply` blind: drift flows both ways. Check `chezmoi diff` direction first (live edits you want to keep must be re-added, not overwritten).
- `wsl --shutdown` kills every running agent — warn before any step that requires it.

## Skills

| Skill | Use for |
|---|---|
| `.claude/skills/dotfiles-setup/` | bootstrap or verify a machine (per-OS checklist with check/fix/verify commands) |
| `.claude/skills/dotfiles-update/` | route a config change to the right layer and apply it |
| `.claude/skills/dotfiles-sync/` | pull live drift back into the repo, review for secrets, commit |
| `.claude/skills/dotfiles-help/` | answer "why is it set up this way" from the docs |
