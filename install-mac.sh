#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "==> $*"; }

# Stow a package, moving any pre-existing real file out of the way first.
# Needed when migrating a machine that already has live configs.
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
# Homebrew
# ---------------------------------------------------------------------------
step "Homebrew"
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  success "Homebrew already installed"
fi

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------
step "Formulae"
BREW_FORMULAE=(
  git gh stow
  tmux starship herdr
  fzf zoxide bat tree
  zsh-syntax-highlighting
  hugo terraform mise neovim
  uv fnm go
)
for pkg in "${BREW_FORMULAE[@]}"; do
  if brew list --formula "$pkg" &>/dev/null; then
    success "$pkg already installed"
  else
    info "Installing $pkg..."
    brew install "$pkg"
  fi
done

step "Casks"
BREW_CASKS=(ghostty)
for pkg in "${BREW_CASKS[@]}"; do
  if brew list --cask "$pkg" &>/dev/null; then
    success "$pkg already installed"
  else
    info "Installing $pkg..."
    brew install --cask "$pkg"
  fi
done

# ---------------------------------------------------------------------------
# Node via fnm
# ---------------------------------------------------------------------------
step "Node (fnm)"
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
# Rust
# ---------------------------------------------------------------------------
step "Rust"
if ! command -v rustup &>/dev/null; then
  info "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
# shellcheck disable=SC1091
source "$HOME/.cargo/env"
rustup component add rust-analyzer 2>/dev/null || true
success "Rust $(rustc --version | awk '{print $2}')"

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

# aws is intentionally not stowed: only the template is tracked and it is
# copied into place below, so linking it into ~/.aws serves no purpose.
PACKAGES=(zsh nvim tmux ghostty starship git ssh claude herdr mise)
for pkg in "${PACKAGES[@]}"; do
  info "Stowing $pkg..."
  stow_pkg "$pkg"
done

# Neovim's colorscheme is gated inside lua/plugins/theme.lua via
# vim.fn.has("mac"), so no platform-specific linking is needed here.

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

  1. Restart your terminal, or: exec zsh

  2. Generate SSH keys:
       dotfiles-gen-git-key your@email.com
       dotfiles-gen-machine-key

  3. Install Docker Desktop:
       https://www.docker.com/products/docker-desktop/

  4. Open herdr and connect the Claude integration
     (this generates ~/.claude/hooks/herdr-agent-state.sh)

  Any config this script replaced was saved as <file>.bak.<timestamp>

EOF
