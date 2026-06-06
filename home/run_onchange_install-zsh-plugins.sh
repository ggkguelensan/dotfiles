#!/bin/sh
# Installs the oh-my-zsh runtime deps that dot_zshrc REFERENCES but chezmoi
# cannot carry as plain files: the powerlevel10k theme and three custom plugins
# (zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions) — plus
# oh-my-zsh itself when absent. Without these a fresh interactive shell prints
# "plugin '…' not found" / "theme 'powerlevel10k/powerlevel10k' not found".
#
# run_onchange: re-runs only when this script's content changes. Every step is
# guarded ([ -d … ]) so re-runs are no-ops once everything is present; failures
# are non-fatal (a bad network must not abort `chezmoi apply`).
# Unix-only (dot_zshrc is unix-only) — .chezmoiignore drops it on Windows.
set -eu

if ! command -v git >/dev/null 2>&1; then
  echo "zsh-plugins: git not found, skipping" >&2
  exit 0
fi

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

# oh-my-zsh itself. KEEP_ZSHRC=yes: chezmoi owns ~/.zshrc — the installer must
# not replace it; RUNZSH/CHSH=no: don't launch a shell or change the login shell.
if [ ! -d "$ZSH_DIR" ]; then
  echo "zsh-plugins: installing oh-my-zsh"
  if command -v curl >/dev/null 2>&1; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      || { echo "zsh-plugins: oh-my-zsh install failed, skipping plugins" >&2; exit 0; }
  else
    echo "zsh-plugins: curl not found, cannot install oh-my-zsh, skipping" >&2
    exit 0
  fi
fi

# Clone one component into ZSH_CUSTOM if it isn't there yet.
ensure() { # $1 = git url, $2 = destination dir
  if [ -d "$2" ]; then
    echo "zsh-plugins: $(basename "$2") present"
  else
    echo "zsh-plugins: cloning $(basename "$2")"
    git clone --depth=1 "$1" "$2" || echo "zsh-plugins: failed to clone $1" >&2
  fi
}

ensure https://github.com/romkatv/powerlevel10k.git         "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
ensure https://github.com/zsh-users/zsh-autosuggestions     "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
ensure https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
ensure https://github.com/zsh-users/zsh-completions         "$ZSH_CUSTOM_DIR/plugins/zsh-completions"
