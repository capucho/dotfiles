#!/usr/bin/env bash
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
fail()    { echo "[FAIL]  $*"; }
step()    { echo ""; echo "==> $*"; }

has() { command -v "$1" >/dev/null 2>&1; }

# Newline-separated record of what could not be installed, reported at the end.
FAILED=""
record_failure() { FAILED="${FAILED}  - $1"$'\n'; }

# Hard gate: stop before a phase whose tools are missing, naming the fix.
# Each argument is "binary|how to get it".
require() {
  local missing="" arg bin hint
  for arg in "$@"; do
    bin="${arg%%|*}"
    hint="${arg#*|}"
    has "$bin" || missing="${missing}  - ${bin}: ${hint}"$'\n'
  done
  if [ -n "$missing" ]; then
    echo ""
    fail "Required tool(s) missing, cannot continue:"
    printf '%s' "$missing"
    echo ""
    exit 1
  fi
}

# install_pkg <package> [binary-to-verify]
# Installs through Omarchy's wrapper so its update channel stays authoritative,
# then verifies the binary actually appeared. Never aborts the whole run.
install_pkg() {
  local pkg="$1" bin="${2:-}"

  if [ -n "$bin" ] && has "$bin"; then
    success "$pkg (provides $bin)"
    return 0
  fi
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    success "$pkg already installed"
    return 0
  fi
  if ! has omarchy; then
    warn "omarchy CLI not found — cannot install $pkg"
    record_failure "$pkg (install via Super+Space > Install > Package)"
    return 0
  fi

  info "Installing $pkg..."
  if ! omarchy pkg add "$pkg"; then
    warn "omarchy pkg add $pkg failed"
    record_failure "$pkg (omarchy pkg add $pkg)"
    return 0
  fi
  # Installing is not the same as working: confirm the binary exists.
  if [ -n "$bin" ] && ! has "$bin"; then
    warn "$pkg installed but '$bin' is not on PATH"
    record_failure "$pkg (installed, but $bin missing from PATH)"
    return 0
  fi
  success "$pkg installed"
}

# Try several package names for the same tool (repos disagree on naming).
install_any() {
  local bin="$1"; shift
  local pkg
  if has "$bin"; then
    success "$bin already available"
    return 0
  fi
  for pkg in "$@"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      install_pkg "$pkg" "$bin"
      return 0
    fi
  done
  warn "none of these packages exist in the repos: $*"
  record_failure "$bin (tried: $*)"
}

# ---------------------------------------------------------------------------
# Preflight — nothing below works without these
# ---------------------------------------------------------------------------
step "Preflight"
require \
  "pacman|this script targets Arch-based Omarchy" \
  "git|needed to clone this repo, so it should already exist" \
  "curl|install with: omarchy pkg add curl"

if has omarchy; then
  success "omarchy CLI found"
else
  warn "omarchy CLI not found — packages must be installed from the menu"
  warn "Super+Space > Install > Package"
fi
success "Preflight passed"

# ---------------------------------------------------------------------------
# Packages. Second field is the binary used to verify the install worked.
# ---------------------------------------------------------------------------
step "Packages"
install_pkg zsh                     zsh
install_pkg stow                    stow
install_pkg tmux                    tmux
install_pkg starship                starship
install_pkg fzf                     fzf
install_pkg zoxide                  zoxide
install_pkg bat                     bat
install_pkg tree                    tree
install_pkg hugo                    hugo
install_pkg terraform               terraform
install_pkg mise                    mise
install_pkg neovim                  nvim
install_pkg ghostty                 ghostty
install_pkg wl-clipboard            wl-copy
install_pkg go                      go
install_pkg zsh-syntax-highlighting

# Homebrew calls it gh; Arch calls it github-cli.
install_any gh github-cli gh

# herdr may only be in the AUR.
step "herdr"
if has herdr; then
  success "herdr already installed"
elif pacman -Si herdr >/dev/null 2>&1; then
  install_pkg herdr herdr
else
  warn "herdr is not in the official repos"
  warn "install from the AUR: Super+Space > Install > AUR > herdr"
  record_failure "herdr (AUR)"
fi

# ---------------------------------------------------------------------------
# Default shell
# ---------------------------------------------------------------------------
step "Default shell"
if ! has zsh; then
  warn "zsh missing — skipping shell change"
elif ! has chsh; then
  warn "chsh missing — set the shell manually: chsh -s \$(command -v zsh)"
elif [ "$(basename "${SHELL:-}")" = "zsh" ]; then
  success "zsh is already the default shell"
else
  info "Setting zsh as default shell..."
  if chsh -s "$(command -v zsh)"; then
    warn "Shell changed — log out and back in for it to take effect"
  else
    warn "chsh failed — run manually: chsh -s \$(command -v zsh)"
  fi
fi

# ---------------------------------------------------------------------------
# Default terminal
# ---------------------------------------------------------------------------
step "Ghostty as default terminal"
if ! has ghostty; then
  warn "ghostty not installed — skipping"
elif has omarchy-install-terminal; then
  current=""
  has omarchy-default-terminal && current="$(omarchy-default-terminal 2>/dev/null || true)"
  if [ "$current" = "ghostty" ]; then
    success "Ghostty already default"
  elif omarchy-install-terminal ghostty; then
    success "Ghostty set as default terminal"
  else
    warn "could not set default terminal automatically"
    warn "set it via Super+Space > Install > Terminal > Ghostty"
  fi
else
  warn "omarchy-install-terminal not found"
  warn "set it via Super+Space > Install > Terminal > Ghostty"
fi

# ---------------------------------------------------------------------------
# Node via fnm
# ---------------------------------------------------------------------------
step "Node (fnm)"
if ! has fnm; then
  info "Installing fnm..."
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://fnm.vercel.app/install \
    | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell \
    || warn "fnm installer failed"
  export PATH="$HOME/.local/bin:$PATH"
fi

if has fnm; then
  eval "$(fnm env --use-on-cd --shell bash)"
  if ! fnm list 2>/dev/null | grep -qE 'v[0-9]+\.'; then
    info "Installing Node LTS..."
    fnm install --lts || warn "fnm install --lts failed"
  fi
  latest="$(fnm list 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)"
  [ -n "$latest" ] && fnm default "$latest" >/dev/null 2>&1 || true
  if has node; then
    success "Node $(node --version)"
  else
    warn "node still not on PATH"
    record_failure "node (via fnm)"
  fi
else
  warn "fnm unavailable — skipping Node, pnpm and Claude Code"
  record_failure "fnm (https://fnm.vercel.app)"
fi

# ---------------------------------------------------------------------------
# npm-based tools — only if npm actually exists
# ---------------------------------------------------------------------------
step "pnpm + Claude Code"
if ! has npm; then
  warn "npm not available (Node install did not complete) — skipping"
  record_failure "pnpm and claude-code (need npm)"
else
  if has pnpm; then
    success "pnpm already installed"
  elif npm install -g pnpm; then
    success "pnpm installed"
  else
    warn "pnpm install failed"; record_failure "pnpm (npm install -g pnpm)"
  fi

  if has claude; then
    success "claude already installed"
  elif npm install -g @anthropic-ai/claude-code; then
    success "claude-code installed"
  else
    warn "claude-code install failed"
    record_failure "claude-code (npm install -g @anthropic-ai/claude-code)"
  fi
fi

# ---------------------------------------------------------------------------
# Rust
# ---------------------------------------------------------------------------
step "Rust"
if has rustup; then
  success "rustup already installed"
else
  info "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path || warn "rustup installer failed"
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
if has rustup; then
  rustup component add rust-analyzer >/dev/null 2>&1 || \
    warn "could not add rust-analyzer component"
  success "Rust $(rustc --version 2>/dev/null | awk '{print $2}')"
else
  record_failure "rust (https://rustup.rs)"
fi

# ---------------------------------------------------------------------------
# uv
# ---------------------------------------------------------------------------
step "uv"
if has uv; then
  success "uv already installed"
elif pacman -Si uv >/dev/null 2>&1; then
  install_pkg uv uv
else
  info "Installing uv via official installer..."
  curl -LsSf https://astral.sh/uv/install.sh | sh || warn "uv installer failed"
  has uv || record_failure "uv (https://astral.sh/uv)"
fi

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
step "Docker"
if has docker; then
  success "Docker already installed"
else
  install_pkg docker docker
  if has docker; then
    if has systemctl && has sudo; then
      sudo systemctl enable --now docker.service || warn "could not enable docker service"
      sudo usermod -aG docker "$USER" || warn "could not add $USER to docker group"
      warn "Log out and back in to use docker without sudo"
    else
      warn "systemctl/sudo unavailable — enable docker manually:"
      warn "  sudo systemctl enable --now docker.service"
      warn "  sudo usermod -aG docker \$USER"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# TPM
# ---------------------------------------------------------------------------
step "TPM"
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
  success "TPM already installed"
else
  mkdir -p "$(dirname "$TPM_DIR")"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR" \
    && success "TPM cloned" \
    || { warn "TPM clone failed"; record_failure "tpm (git clone)"; }
fi

# ---------------------------------------------------------------------------
# Stow — the part that actually links the configs, so require the tool
# ---------------------------------------------------------------------------
step "Stow packages"
require "stow|omarchy pkg add stow"
cd "$DOTFILES"

# Create these as REAL directories first. If they don't exist, stow folds the
# whole directory into one symlink pointing at this repo, and anything written
# there at runtime lands inside the repo — SSH private keys, git config.local,
# herdr sockets, Claude's cache and history. With the directory present, stow
# links only the individual tracked files.
mkdir -p "$HOME/.ssh" "$HOME/.claude" "$HOME/.config/git" \
         "$HOME/.config/herdr" "$HOME/.config/tmux"

# Neovim: Omarchy ships its own LazyVim config in ~/.config/nvim; stowing
# replaces it with this repo's (also LazyVim). The colorscheme stays unset on
# Linux — see lua/plugins/theme.lua — so Omarchy's theme system keeps control.
#
# aws is deliberately not stowed; the template is copied into place below.
for pkg in zsh nvim tmux ghostty starship git ssh claude herdr mise; do
  info "Stowing $pkg..."
  # Move any pre-existing real file aside so stow can take over.
  conflicts="$(stow --no --target="$HOME" "$pkg" 2>&1 \
    | sed -n 's/.*existing target \([^ ]*\) since.*/\1/p')"
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
  stow --restow --target="$HOME" "$pkg" || warn "stow $pkg reported a problem"
done

HOST="$(hostname -s 2>/dev/null || hostname)"
if [ -d "$DOTFILES/hosts/$HOST" ]; then
  info "Stowing host overrides for $HOST..."
  stow --restow --target="$HOME" --dir="$DOTFILES/hosts" "$HOST" \
    || warn "host stow failed"
else
  warn "No host-specific config for $HOST (create hosts/$HOST to add one)"
fi
success "Stow complete"

chmod 700 "$HOME/.ssh" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Git identity — may already live in ~/.gitconfig, which git reads after (and
# so takes precedence over) ~/.config/git/config. Only prompt if neither has one.
# ---------------------------------------------------------------------------
step "Git identity"
if git config --global user.email >/dev/null 2>&1 \
  && git config --global user.name >/dev/null 2>&1; then
  success "Already set: $(git config --global user.name) <$(git config --global user.email)>"
else
  GIT_CONFIG_LOCAL="$HOME/.config/git/config.local"
  echo ""
  read -rp "Git name:  " GIT_NAME
  read -rp "Git email: " GIT_EMAIL
  mkdir -p "$(dirname "$GIT_CONFIG_LOCAL")"
  printf '[user]\n\tname = %s\n\temail = %s\n' "$GIT_NAME" "$GIT_EMAIL" > "$GIT_CONFIG_LOCAL"
  success "Written to $GIT_CONFIG_LOCAL"
fi

# ---------------------------------------------------------------------------
# AWS config
# ---------------------------------------------------------------------------
step "AWS config"
if [ -f "$HOME/.aws/config" ]; then
  success "AWS config already exists (left untouched)"
else
  mkdir -p "$HOME/.aws"
  cp "$DOTFILES/aws/.aws/config.template" "$HOME/.aws/config"
  info "Created from template — edit ~/.aws/config to set your profiles"
fi

# ---------------------------------------------------------------------------
# Tmux plugins
# ---------------------------------------------------------------------------
step "Tmux plugins"
if [ -x "$TPM_DIR/bin/install_plugins" ]; then
  TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins" \
    "$TPM_DIR/bin/install_plugins" >/dev/null 2>&1 \
    && success "Tmux plugins installed" \
    || warn "TPM install returned non-zero — run prefix+I inside tmux"
else
  warn "TPM not present — skipping plugin install"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
if [ -n "$FAILED" ]; then
  echo "  COMPLETED WITH ISSUES"
  echo "============================================================"
  echo ""
  echo "  These could not be installed:"
  printf '%s' "$FAILED"
  echo "  Everything else was configured. Re-run this script after"
  echo "  resolving them — it is safe to run repeatedly."
else
  echo "  DONE"
  echo "============================================================"
fi
cat <<'EOF'

  Next steps:

  1. Log out and back in (shell change and docker group)

  2. Generate SSH keys:
       dotfiles-gen-git-key your@email.com
       dotfiles-gen-machine-key

  3. Open herdr and connect the Claude integration
     (this generates ~/.claude/hooks/herdr-agent-state.sh)

  Any config replaced by this script was saved as <file>.bak.<timestamp>

EOF
