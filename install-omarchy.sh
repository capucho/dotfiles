#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "==> $*"; }

# Install via Omarchy's wrapper so its update channel stays authoritative.
# Never call pacman/paru directly.
pkg_add() {
  local pkg="$1"
  if pacman -Q "$pkg" &>/dev/null; then
    success "$pkg already installed"
  elif command -v omarchy &>/dev/null; then
    info "Installing $pkg..."
    omarchy pkg add "$pkg"
  else
    warn "omarchy CLI not found — install $pkg via Super+Space > Install > Package"
  fi
}

# Stow a package, moving any pre-existing real file out of the way first.
stow_pkg() {
  local pkg="$1" ts conflicts f target
  conflicts="$(stow --no --target="$HOME" "$pkg" 2>&1 \
    | sed -n 's/.*existing target \([^ ]*\) since.*/\1/p' || true)"
  if [ -n "$conflicts" ]; then
    ts="$(date +%s)"
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      target="$HOME/$f"
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        warn "Backing up $target -> $target.bak.$ts"
        mv "$target" "$target.bak.$ts"
      fi
    done <<< "$conflicts"
  fi
  stow --restow --target="$HOME" "$pkg"
}

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------
step "Packages"
PACKAGES=(
  zsh git github-cli stow
  tmux starship
  fzf zoxide bat tree
  zsh-syntax-highlighting
  hugo terraform mise neovim ghostty
  wl-clipboard
)
for pkg in "${PACKAGES[@]}"; do
  pkg_add "$pkg"
done

# herdr may not be in the official repos; try, then fall back to AUR.
step "herdr"
if ! command -v herdr &>/dev/null; then
  if pacman -Si herdr &>/dev/null 2>&1; then
    pkg_add herdr
  else
    warn "herdr not in official repos."
    warn "Install from AUR: Super+Space > Install > AUR > herdr"
  fi
else
  success "herdr already installed"
fi

# ---------------------------------------------------------------------------
# Default shell
# ---------------------------------------------------------------------------
step "Default shell"
if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
  info "Setting zsh as default shell..."
  chsh -s "$(command -v zsh)"
  warn "Shell changed — log out and back in for it to take effect"
else
  success "zsh is already the default shell"
fi

# ---------------------------------------------------------------------------
# Default terminal
# ---------------------------------------------------------------------------
step "Ghostty as default terminal"
if command -v omarchy-install-terminal &>/dev/null; then
  if [ "$(omarchy-default-terminal 2>/dev/null || true)" != "ghostty" ]; then
    omarchy-install-terminal ghostty
    success "Ghostty set as default terminal"
  else
    success "Ghostty already default"
  fi
else
  warn "omarchy-install-terminal not found"
  warn "Set it manually: Super+Space > Install > Terminal > Ghostty"
fi

# ---------------------------------------------------------------------------
# Node via fnm
# ---------------------------------------------------------------------------
step "Node (fnm)"
if ! command -v fnm &>/dev/null; then
  info "Installing fnm..."
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://fnm.vercel.app/install \
    | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell
fi
export PATH="$HOME/.local/bin:$PATH"
eval "$(fnm env --use-on-cd --shell bash)"
if ! fnm list 2>/dev/null | grep -qE 'v[0-9]+\.'; then
  info "Installing Node LTS..."
  fnm install --lts
fi
fnm default "$(fnm list | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1)" 2>/dev/null || true
success "Node $(node --version 2>/dev/null || echo '(restart shell)')"

step "pnpm + Claude Code"
command -v pnpm  &>/dev/null || npm install -g pnpm
command -v claude &>/dev/null || npm install -g @anthropic-ai/claude-code
success "pnpm + claude code installed"

# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------
step "Go"
pkg_add go

# ---------------------------------------------------------------------------
# Rust
# ---------------------------------------------------------------------------
step "Rust"
if ! command -v rustup &>/dev/null; then
  info "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
# shellcheck disable=SC1091
source "$HOME/.cargo/env" 2>/dev/null || true
rustup component add rust-analyzer 2>/dev/null || true
success "Rust installed"

# ---------------------------------------------------------------------------
# uv
# ---------------------------------------------------------------------------
step "uv"
if ! command -v uv &>/dev/null; then
  if pacman -Si uv &>/dev/null 2>&1; then
    pkg_add uv
  else
    info "Installing uv via official installer..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
fi
success "uv installed"

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
step "Docker"
if ! command -v docker &>/dev/null; then
  pkg_add docker
  sudo systemctl enable --now docker.service
  sudo usermod -aG docker "$USER"
  warn "Added $USER to the docker group — log out and back in to use docker without sudo"
else
  success "Docker already installed"
fi

# ---------------------------------------------------------------------------
# TPM — Tmux Plugin Manager
# ---------------------------------------------------------------------------
step "TPM"
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
  success "TPM cloned"
else
  success "TPM already installed"
fi

# ---------------------------------------------------------------------------
# Stow packages
# ---------------------------------------------------------------------------
step "Stow packages"
cd "$DOTFILES"

# Create these as REAL directories before stowing. If they don't exist, stow
# "folds" the whole directory into a single symlink pointing at this repo, and
# anything written there at runtime lands inside the repo. That would put SSH
# private keys, git config.local, herdr sockets and Claude's cache/history
# inside a git repository. With the directory present, stow links only the
# individual tracked files and leaves runtime state in $HOME.
mkdir -p "$HOME/.ssh" "$HOME/.claude" "$HOME/.config/git" \
         "$HOME/.config/herdr" "$HOME/.config/tmux"

# Neovim note: Omarchy ships its own LazyVim config in ~/.config/nvim.
# Stowing replaces it with this repo's config (also LazyVim based). The
# colorscheme stays unset on Linux — see lua/plugins/theme.lua — so the
# Omarchy theme system keeps control of it.
#
# aws is intentionally not stowed; the template is copied into place below.
PACKAGES=(zsh nvim tmux ghostty starship git ssh claude herdr mise)
for pkg in "${PACKAGES[@]}"; do
  info "Stowing $pkg..."
  stow_pkg "$pkg"
done

HOST="$(hostname -s)"
if [ -d "$DOTFILES/hosts/$HOST" ]; then
  info "Stowing host overrides for $HOST..."
  stow --restow --target="$HOME" --dir="$DOTFILES/hosts" "$HOST"
else
  warn "No host-specific config for $HOST (expected hosts/$HOST)"
fi

success "All packages stowed"

# ---------------------------------------------------------------------------
# SSH permissions
# ---------------------------------------------------------------------------
step "SSH permissions"
chmod 700 "$HOME/.ssh" 2>/dev/null || true
success "~/.ssh permissions set"

# ---------------------------------------------------------------------------
# Git identity
# ---------------------------------------------------------------------------
step "Git identity"
GIT_CONFIG_LOCAL="$HOME/.config/git/config.local"
if [ ! -f "$GIT_CONFIG_LOCAL" ]; then
  echo ""
  read -rp "Git name:  " GIT_NAME
  read -rp "Git email: " GIT_EMAIL
  mkdir -p "$(dirname "$GIT_CONFIG_LOCAL")"
  cat > "$GIT_CONFIG_LOCAL" <<EOF
[user]
	name = $GIT_NAME
	email = $GIT_EMAIL
EOF
  success "Git identity configured"
else
  success "Git identity already configured"
fi

# ---------------------------------------------------------------------------
# AWS config
# ---------------------------------------------------------------------------
step "AWS config"
AWS_CONFIG="$HOME/.aws/config"
if [ ! -f "$AWS_CONFIG" ]; then
  mkdir -p "$HOME/.aws"
  cp "$DOTFILES/aws/.aws/config.template" "$AWS_CONFIG"
  info "AWS config created from template — edit $AWS_CONFIG to set your profiles"
else
  success "AWS config already exists (left untouched)"
fi

# ---------------------------------------------------------------------------
# Tmux plugins
# ---------------------------------------------------------------------------
step "Tmux plugins"
if [ -x "$TPM_DIR/bin/install_plugins" ]; then
  TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins" \
    "$TPM_DIR/bin/install_plugins" >/dev/null 2>&1 || \
    warn "TPM install returned non-zero — run prefix+I inside tmux"
  success "Tmux plugins installed"
fi

# ---------------------------------------------------------------------------
# Post-install checklist
# ---------------------------------------------------------------------------
cat <<'EOF'

============================================================
  DONE — post-install checklist
============================================================

  1. Log out and back in (picks up the shell change and docker group)

  2. Generate SSH keys:
       dotfiles-gen-git-key your@email.com
       dotfiles-gen-machine-key

  3. Open herdr and connect the Claude integration
     (this generates ~/.claude/hooks/herdr-agent-state.sh)

  Any config this script replaced was saved as <file>.bak.<timestamp>

EOF
