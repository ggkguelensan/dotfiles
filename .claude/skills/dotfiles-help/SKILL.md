---
name: dotfiles-help
description: Explain the dotfiles setup, its layers and principles — answering from the repo's docs with concrete setting IDs and the WHY. Use when user asks "why is this configured this way", "explain the setup", "how do the layers work", "what does this setting do", "объясни настройку", "почему так настроено", "как устроены слои".
---

# Explain the setup

Answer questions **from the docs, not from memory** — the docs encode verified, version-gated facts (VS Code setting scopes shift between releases). Always give the exact setting ID / file path, the layer it lives in, and the WHY.

## Procedure

1. Map the question to its doc:

| Question is about | Read |
|---|---|
| Philosophy: minimal defaults vs heavy customization, what's worth managing, config-as-code vs Settings Sync, runtime guards vs templates | `docs/principles.md` |
| Where a setting lives, precedence ladder, setting scopes, workspace trust, why a value is in THAT file | `docs/layer-map.md` |
| Agent supervision: attention/notification stack, window topology and RAM cost, terminal persistence (reconnect vs revive, tmux), node/fnm stability | `docs/agent-supervision.md` |
| How to *perform* a change (procedure, not theory) | `.claude/skills/dotfiles-update/SKILL.md` |
| Machine bootstrap / verification steps | `.claude/skills/dotfiles-setup/SKILL.md` |

2. Answer with: setting ID or file path → layer → rationale (1–3 sentences, citing the doc's reasoning). Quote version-gated facts as the doc states them; don't "update" them from memory.
3. If the question spans OSes, state the per-OS difference explicitly: three independent repo instances, each applying its own slice via `home/.chezmoiignore.tmpl`.
4. Chat may be in Russian; the docs and setting IDs stay English — answer in the user's language, keep identifiers verbatim.

## Write-back rule (doc gap)

If answering required reasoning or research beyond what the docs say:

1. Answer the user first.
2. Append the resolved finding to the matching doc — `principles.md` for philosophy, `layer-map.md` for routing/scope facts, `agent-supervision.md` for supervision mechanics. Keep it short, factual, with setting IDs.
3. Tell the user the doc was updated (CLAUDE.md write-back rule).

## Routing examples

- "Why is terminal scrollback persistence in the Windows settings file and not in a repo's `.vscode/`?" → `layer-map.md`: `terminal.integrated.persistentSessionScrollback` is application-scoped — legal only in the user layer; workspace values are silently ignored.
- "Почему tmux, если VS Code и так восстанавливает терминалы?" → `agent-supervision.md`: persistent sessions *reconnect* across window reloads, but after server death (monthly VS Code update, `wsl --shutdown`, OOM) they only *revive* scrollback text — the agent process is gone; tmux is the survival layer.
- "Why runtime guards instead of chezmoi templates in `.zshrc`?" → `principles.md`: a guarded file works on any machine even outside chezmoi; template only true per-OS divergence.
- "Куда положить настройку X?" → that's a change, not a question — switch to the `dotfiles-update` skill.
