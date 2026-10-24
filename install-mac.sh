#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "==> $*"; }

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------
step "Homebrew"
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  success "Homebrew already installed"
fi

# ---------------------------------------------------------------------------
# Core packages
# ---------------------------------------------------------------------------
step "Core packages"
BREW_PACKAGES=(
  git gh stow
  tmux ghostty starship herdr
  fzf zoxide bat tree
  zsh-syntax-highlighting
  hugo terraform mise neovim
  uv
)
for pkg in "${BREW_PACKAGES[@]}"; do
  if brew list "$pkg" &>/dev/null; then
    success "$pkg already installed"
  else
    info "Installing $pkg..."
    brew install "$pkg"
  fi
done

# ---------------------------------------------------------------------------
# fnm — Node version management
# ---------------------------------------------------------------------------
step "fnm + Node"
if ! command -v fnm &>/dev/null; then
  brew install fnm
fi
eval "$(fnm env --use-on-cd --shell bash)"
if ! fnm list | grep -q "lts"; then
  info "Installing Node LTS..."
  fnm install --lts
  fnm use lts-latest
fi
success "Node $(node --version) via fnm"

# ---------------------------------------------------------------------------
# pnpm
# ---------------------------------------------------------------------------
step "pnpm"
if ! command -v pnpm &>/dev/null; then
  npm install -g pnpm
fi
success "pnpm $(pnpm --version)"

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------
step "Claude Code"
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
fi
success "claude installed"

# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------
step "Go"
if ! command -v go &>/dev/null; then
  brew install go
fi
success "Go $(go version | awk '{print $3}')"

# ---------------------------------------------------------------------------
# Rust
# ---------------------------------------------------------------------------
step "Rust"
if ! command -v rustup &>/dev/null; then
  info "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
source "$HOME/.cargo/env"
rustup component add rust-analyzer 2>/dev/null || true
success "Rust $(rustc --version | awk '{print $2}')"

# ---------------------------------------------------------------------------
# TPM — Tmux Plugin Manager
# ---------------------------------------------------------------------------
step "TPM"
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  success "TPM cloned"
else
  success "TPM already installed"
fi

# ---------------------------------------------------------------------------
# GNU Stow — symlink packages
# ---------------------------------------------------------------------------
step "Stow packages"
cd "$DOTFILES"

PACKAGES=(zsh nvim tmux ghostty starship git ssh claude herdr aws mise)
for pkg in "${PACKAGES[@]}"; do
  info "Stowing $pkg..."
  stow --restow --target="$HOME" "$pkg"
done

# Mac-only: theme.lua for neovim
info "Stowing nvim theme (Mac)..."
mkdir -p "$HOME/.config/nvim/lua/plugins"
ln -sf "$DOTFILES/nvim/.config/nvim/lua/plugins/theme.lua" \
  "$HOME/.config/nvim/lua/plugins/theme.lua" 2>/dev/null || true

# Host-specific overrides
HOSTNAME=$(hostname)
HOST_DIR="$DOTFILES/hosts/$HOSTNAME"
if [ -d "$HOST_DIR" ]; then
  info "Stowing host overrides for $HOSTNAME..."
  stow --restow --target="$HOME" --dir="$DOTFILES/hosts" "$HOSTNAME"
else
  warn "No host-specific config for $HOSTNAME"
fi

success "All packages stowed"

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
AWS_TEMPLATE="$DOTFILES/aws/.aws/config.template"
if [ ! -f "$AWS_CONFIG" ] && [ -f "$AWS_TEMPLATE" ]; then
  mkdir -p "$HOME/.aws"
  cp "$AWS_TEMPLATE" "$AWS_CONFIG"
  info "AWS config created from template — edit $AWS_CONFIG to set your profiles"
else
  success "AWS config already exists"
fi

# ---------------------------------------------------------------------------
# TPM plugin install
# ---------------------------------------------------------------------------
step "Installing tmux plugins"
if [ -f "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" ]; then
  TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins" \
    "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" 2>/dev/null || true
  success "Tmux plugins installed"
fi

# ---------------------------------------------------------------------------
# Post-install checklist
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  DONE — post-install checklist:"
echo "============================================================"
echo ""
echo "  1. Generate SSH keys:"
echo "       source ~/.zshrc"
echo "       dotfiles-gen-git-key your@email.com"
echo "       dotfiles-gen-machine-key"
echo ""
echo "  2. Install Docker Desktop:"
echo "       https://www.docker.com/products/docker-desktop/"
echo ""
echo "  3. Connect herdr + Claude integration:"
echo "       Open herdr → connect Claude"
echo ""
echo "  4. Restart your terminal (or: source ~/.zshrc)"
echo ""
