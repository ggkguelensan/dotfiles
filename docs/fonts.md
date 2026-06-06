# Fonts: full glyph coverage everywhere

One font name is wired through the whole setup: **MesloLGS NF** — the
powerlevel10k-patched Nerd Font build. It carries every glyph this stack needs:
p10k prompt segments, powerline separators, Claude Code spinners/TUI borders,
codicons-adjacent symbols, box drawing.

## The one fact that saves you time

**In Remote-WSL (and any VS Code remote), the terminal renders on the CLIENT.**
Fonts are installed on **Windows / macOS** — installing fonts *inside* WSL does
nothing for VS Code or Windows Terminal. WSL-side fonts only matter for WSLg
GUI apps.

## Install

### Windows

Download the four TTFs and for each: right-click → **Install** (or
*Install for all users* so terminals running elevated see them too):

- [MesloLGS NF Regular](https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf)
- [MesloLGS NF Bold](https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf)
- [MesloLGS NF Italic](https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf)
- [MesloLGS NF Bold Italic](https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf)

(Canonical source + alternatives: [p10k font guide](https://github.com/romkatv/powerlevel10k/blob/master/font.md).)

CLI alternative if oh-my-posh is around: `oh-my-posh font install meslo`.

### macOS

```sh
brew install --cask font-meslo-lg-nerd-font        # Nerd Fonts Meslo family
brew install --cask font-jetbrains-mono-nerd-font  # fallback in the VS Code chain
```

Or install the same four p10k TTFs above via Font Book (double-click → Install) —
the p10k build is the reference variant the prompt was designed against.

### WSL / Linux (only for WSLg GUI apps or native-Linux terminals)

```sh
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
for v in "Regular" "Bold" "Italic" "Bold%20Italic"; do
  curl -fLO "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20${v}.ttf"
done
fc-cache -fv
```

Emoji in native-Linux terminals: `sudo apt install fonts-noto-color-emoji`.
(In WSL, emoji come from the Windows-side renderer — nothing to install.)

### More fonts

Browse/download other patched families (JetBrainsMono NF, FiraCode NF, …):
[nerdfonts.com/font-downloads](https://www.nerdfonts.com/font-downloads).
Prefer the `*Nerd Font` (not `*NF Mono`) variants for double-width glyph rendering
in editor UIs.

## Where the font is referenced in this repo

| Consumer | Key | File |
|---|---|---|
| VS Code editor (code) | `editor.fontFamily: "'MesloLGS NF'"` | `home/.chezmoitemplates/vscode-settings.json.tmpl` |
| VS Code terminal (zsh, agents) | `terminal.integrated.fontFamily` + `fontLigatures` | same |
| VS Code glyph fallback | `terminal.integrated.customGlyphs: true` — box-drawing/powerline drawn pixel-perfect even without the font | same |
| zsh prompt | p10k is *designed* for MesloLGS NF (`POWERLEVEL9K_MODE` auto) | `home/dot_p10k.zsh` |
| Ghostty (and cmux via inheritance) | `font-family = MesloLGS NF` | `home/dot_config/ghostty/config` |

Fallback chain used in VS Code: `'MesloLGS NF', 'JetBrainsMono Nerd Font', monospace`.

## Verify

- zsh: `p10k debug` segments show no `?`/tofu boxes; `echo "  ❯"` renders arrows/git glyphs.
- VS Code: terminal prompt arrows are solid, Claude Code spinner is smooth, no □ in the agent TUI.
- Ghostty: `ghostty +list-fonts | grep -i meslo` shows the family.
