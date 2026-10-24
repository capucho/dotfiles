#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "==> $*"; }

pkg_add() {
  local pkg="$1"
  if pacman -Q "$pkg" &>/dev/null; then
    success "$pkg already installed"
  else
    info "Installing $pkg..."
    omarchy pkg add "$pkg"
  fi
}

# ---------------------------------------------------------------------------
# zsh
# ---------------------------------------------------------------------------
step "zsh"
pkg_add zsh
if [ "$SHELL" != "$(which zsh)" ]; then
  info "Setting zsh as default shell..."
  chsh -s "$(which zsh)"
  warn "Shell changed — log out and back in for it to take effect"
else
  success "zsh is already the default shell"
fi

# ---------------------------------------------------------------------------
# Core packages
# ---------------------------------------------------------------------------
step "Core packages"
PACKAGES=(
  git gh stow
  tmux starship herdr
  fzf zoxide bat tree
  zsh-syntax-highlighting
  hugo terraform mise neovim ghostty
)
for pkg in "${PACKAGES[@]}"; do
  pkg_add "$pkg"
done

# ---------------------------------------------------------------------------
# Set ghostty as default terminal
# ---------------------------------------------------------------------------
step "Ghostty as default terminal"
if command -v omarchy-default-terminal &>/dev/null; then
  if [ "$(omarchy-default-terminal 2>/dev/null)" != "ghostty" ]; then
    omarchy-install-terminal ghostty
    success "Ghostty set as default terminal"
  else
    success "Ghostty already default"
  fi
else
  warn "omarchy-install-terminal not found — set terminal manually via Omarchy menu"
fi

# ---------------------------------------------------------------------------
# fnm — Node version management
# ---------------------------------------------------------------------------
step "fnm + Node"
if ! command -v fnm &>/dev/null; then
  info "Installing fnm..."
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell
fi
export PATH="$HOME/.local/bin:$PATH"
eval "$(fnm env --use-on-cd --shell bash)"
if ! fnm list 2>/dev/null | grep -q "lts\|v[0-9]"; then
  info "Installing Node LTS..."
  fnm install --lts
  fnm use lts-latest
fi
success "Node $(node --version 2>/dev/null || echo 'installed') via fnm"

# ---------------------------------------------------------------------------
# pnpm + Claude Code
# ---------------------------------------------------------------------------
step "pnpm + Claude Code"
if ! command -v pnpm &>/dev/null; then
  npm install -g pnpm
fi
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
fi
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
source "$HOME/.cargo/env" 2>/dev/null || true
rustup component add rust-analyzer 2>/dev/null || true
success "Rust installed"

# ---------------------------------------------------------------------------
# uv — Python tooling
# ---------------------------------------------------------------------------
step "uv"
if ! command -v uv &>/dev/null; then
  if pacman -Si uv &>/dev/null 2>&1; then
    pkg_add uv
  else
    info "Installing uv via installer..."
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
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER"
  warn "Added $USER to docker group — log out and back in to use docker without sudo"
else
  success "Docker already installed"
fi

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

# Omarchy: stow everything except the Mac-only theme
PACKAGES=(zsh nvim tmux ghostty starship git ssh claude herdr aws mise)
for pkg in "${PACKAGES[@]}"; do
  info "Stowing $pkg..."
  stow --restow --target="$HOME" "$pkg"
done

# Remove Mac-only theme.lua if it got stowed somehow
if [ -L "$HOME/.config/nvim/lua/plugins/theme.lua" ]; then
  rm "$HOME/.config/nvim/lua/plugins/theme.lua"
  info "Removed Mac-only theme.lua — Omarchy theme system will manage colorscheme"
fi

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
echo "  1. Log out and back in (shell change + docker group)"
echo ""
echo "  2. Generate SSH keys:"
echo "       source ~/.zshrc"
echo "       dotfiles-gen-git-key your@email.com"
echo "       dotfiles-gen-machine-key"
echo ""
echo "  3. Connect herdr + Claude integration:"
echo "       Open herdr → connect Claude"
echo ""
echo "  4. Restart your terminal"
echo ""
