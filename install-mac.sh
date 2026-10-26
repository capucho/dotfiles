#!/usr/bin/env bash
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
fail()    { echo "[FAIL]  $*"; }
step()    { echo ""; echo "==> $*"; }

has() { command -v "$1" >/dev/null 2>&1; }

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

SHADOWED=""

# brew_install <formula|cask> <package> [binary-to-verify]
#
# Homebrew is the owner of record on macOS, so presence of the *binary* is not
# enough: a manual install in /usr/local never receives `brew upgrade`. We
# therefore check Homebrew itself, install if absent, then verify the binary
# and report anything outside the Homebrew prefix that shadows it.
brew_install() {
  local kind="$1" pkg="$2" bin="${3:-}" loc

  if brew list --"$kind" "$pkg" >/dev/null 2>&1; then
    success "$pkg already installed"
  else
    info "Installing $pkg..."
    if [ "$kind" = "cask" ]; then
      brew install --cask "$pkg" \
        || { warn "failed to install $pkg"; record_failure "$pkg (brew install --cask $pkg)"; return 0; }
    else
      brew install "$pkg" \
        || { warn "failed to install $pkg"; record_failure "$pkg (brew install $pkg)"; return 0; }
    fi
    success "$pkg installed"
  fi

  [ -z "$bin" ] && return 0

  if ! has "$bin"; then
    warn "$pkg installed but '$bin' is not on PATH"
    record_failure "$pkg (installed, but $bin missing from PATH)"
    return 0
  fi

  # Casks install into /Applications by design, so a path outside the
  # Homebrew prefix is expected and not worth reporting.
  [ "$kind" = "cask" ] && return 0

  loc="$(command -v "$bin")"
  case "$loc" in
    "$BREW_PREFIX"/*) ;;
    # Apple's own tools in /usr/bin are expected and managed by macOS.
    /usr/bin/*) ;;
    *) warn "'$bin' resolves to $loc, outside Homebrew"
       SHADOWED="${SHADOWED}  - $bin -> $loc"$'\n' ;;
  esac
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
step "Preflight"
require \
  "git|install Xcode command line tools: xcode-select --install" \
  "curl|ships with macOS; a missing curl means a broken system"

if ! has brew; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || { fail "Homebrew install failed"; exit 1; }
  # Make brew usable in this shell without a restart.
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && eval "$("$p" shellenv)" && break
  done
fi
require "brew|https://brew.sh"
BREW_PREFIX="$(brew --prefix)"
success "Preflight passed (Homebrew prefix: $BREW_PREFIX)"

# ---------------------------------------------------------------------------
# Formulae. Third field is the binary used to verify the install worked.
# ---------------------------------------------------------------------------
step "Formulae"
brew_install formula git        git
brew_install formula gh         gh
brew_install formula stow       stow
brew_install formula tmux       tmux
brew_install formula starship   starship
brew_install formula herdr      herdr
brew_install formula fzf        fzf
brew_install formula zoxide     zoxide
brew_install formula bat        bat
brew_install formula tree       tree
brew_install formula hugo       hugo
brew_install formula terraform  terraform
brew_install formula mise       mise
brew_install formula neovim     nvim
brew_install formula uv         uv
brew_install formula fnm        fnm
brew_install formula go         go
brew_install formula zsh-syntax-highlighting
brew_install formula zsh-autosuggestions
brew_install formula zsh-history-substring-search

step "Casks"
brew_install cask ghostty ghostty

# ---------------------------------------------------------------------------
# Node via fnm
# ---------------------------------------------------------------------------
step "Node (fnm)"
if ! has fnm; then
  warn "fnm unavailable — skipping Node, pnpm and Claude Code"
  record_failure "fnm (brew install fnm)"
else
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
require "stow|brew install stow"
cd "$DOTFILES"

# Create these as REAL directories first. If they don't exist, stow folds the
# whole directory into one symlink pointing at this repo, and anything written
# there at runtime lands inside the repo — SSH private keys, git config.local,
# herdr sockets, Claude's cache and history. With the directory present, stow
# links only the individual tracked files.
mkdir -p "$HOME/.ssh" "$HOME/.claude" "$HOME/.config/git" \
         "$HOME/.config/herdr" "$HOME/.config/tmux"

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

# Neovim's colorscheme is gated inside lua/plugins/theme.lua via
# vim.fn.has("mac"), so no platform-specific linking is needed here.

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

if [ -n "$SHADOWED" ]; then
  echo ""
  echo "  These tools resolve outside Homebrew, so they will not receive"
  echo "  'brew upgrade'. Consider removing the unmanaged copy:"
  printf '%s' "$SHADOWED"
fi

cat <<'EOF'

  Next steps:

  1. Restart your terminal, or: exec zsh

  2. Generate SSH keys:
       dotfiles-gen-git-key your@email.com
       dotfiles-gen-machine-key

  3. Install Docker Desktop:
       https://www.docker.com/products/docker-desktop/

  4. Open herdr and connect the Claude integration
     (this generates ~/.claude/hooks/herdr-agent-state.sh)

  Any config replaced by this script was saved as <file>.bak.<timestamp>

EOF
