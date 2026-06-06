---
name: dotfiles-sync
description: Pull local config drift back into the dotfiles repo, review the diff for secrets and machine-specific leakage, and commit. Also refreshes the statusline external. Use when user says "sync dotfiles", "pull drift", "re-add", "I changed settings live", "синхронизируй дотфайлы", "подтяни изменения", "затащи правки в репо".
---

# Sync: pull live drift back into the repo

The repo is the source of truth, but humans (and the VS Code settings UI) edit live files. This skill reconciles — in the right direction.

## 1. See the drift and decide direction

- `chezmoi status` — list targets that differ.
- `chezmoi diff` — shows what `apply` WOULD do (source → live). If a live file holds a change you want to KEEP, the diff looks like apply would *remove* it — that is drift to **re-add**, not to apply.
- Per file decide: live wins → re-add; source wins → apply; both changed → manual merge in source, then apply.

## 2. Pull live changes into source

- Preferred (surgical): `chezmoi re-add ~/.zshrc` — one file at a time.
- `chezmoi re-add` with no args re-adds everything changed — riskier; review first.
- **Templates (`.tmpl`) cannot be re-added** — chezmoi refuses (it would clobber the template with rendered output). Port the live change into the template by hand, then confirm `chezmoi diff` for that target is empty.

## 3. Review BEFORE commit (secrets gate)

Work in the source repo (`chezmoi source-path` → `~/dotfiles`):

1. `git -C ~/dotfiles diff` — read every hunk.
2. Token grep:
   `git -C ~/dotfiles diff | grep -nEi 'ghp_|github_pat_|sk-ant-|AKIA|xox[baprs]-|api[_-]?key|secret|token|password|Bearer '`
3. Machine-specific leakage grep (absolute paths that should be `~`, `$HOME`, or template data):
   `git -C ~/dotfiles diff | grep -nE '/home/[a-z]+/|/Users/[A-Za-z]+/|C:\\\\Users'`
4. Anything secret or machine-local → move it to an unmanaged local file (`~/.claude/settings.local.json`, a `*.local` include) and strip it from the diff. Remember: `home/private_dot_claude/settings.json.tmpl` is the PUBLIC subset.

## 4. Commit / push

- Conventional message, e.g. `chore(sync): pull live drift from <hostname>`, `feat(zsh): add worktree aliases`.
- **Push only if the user confirms** — three independent machines pull from this repo.
- Remind the user: other machines pick the change up with `chezmoi update` (pull + apply).

## Statusline external

`statusline.sh` is pulled from github.com/ggkguelensan/claude-code-statusline via `home/.chezmoiexternal.toml` — it is NOT part of this repo's source files.

- Normal: `chezmoi apply` re-downloads when the external's `refreshPeriod` elapses.
- Force now (after the statusline repo gets a new commit): `chezmoi --refresh-externals apply`.
- Never patch the downloaded `~/.claude/statusline.sh` in place — drift there is overwritten on the next refresh. Change it in its own repo, then force-refresh.
