export EDITOR="nvim"
export VISUAL="nvim"
export LANG="en_US.UTF-8"

# $SHELL reports the passwd entry, not the shell actually running. Ghostty is
# configured to launch zsh directly, so on a machine where chsh has not taken
# effect yet $SHELL still says bash and anything deriving a shell from it —
# tmux panes most visibly — would open bash inside a zsh terminal. Point it at
# the zsh we are in. A no-op once chsh has applied.
if [ -n "${ZSH_VERSION:-}" ]; then
  export SHELL="${commands[zsh]:-$SHELL}"
fi

# Keep PATH entries unique — several tools below prepend unconditionally.
typeset -gU path

# Local binaries (fnm, uv and other installers land here on Linux)
export PATH="$HOME/.local/bin:$PATH"

# Homebrew. Run last of the PATH prepends so brew-managed tools take
# precedence over stray manual installs in /usr/local (macOS puts
# /usr/local/bin ahead of /opt/homebrew/bin by default). Handles both
# Apple Silicon (/opt/homebrew) and Intel (/usr/local) prefixes.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$_brew" ]; then
    eval "$("$_brew" shellenv)"
    break
  fi
done
unset _brew

# fnm — Node version management.
# Guard on the binary, not a fixed dir: brew installs to /opt/homebrew/bin,
# the Linux installer to ~/.local/bin.
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Go
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$PATH:$GOBIN"

# Rust (rustup managed)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# SSH
export OPTIPLEX_IP="192.168.0.115"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY HIST_REDUCE_BLANKS

# Vi mode. Set before fzf so its widgets bind into the vi keymaps.
bindkey -v

# Completion
autoload -Uz compinit && compinit

# tmux autostart — attach to existing session or create one
# disabled by default; uncomment to enable
# if command -v tmux &>/dev/null \
#   && [ -z "$TMUX" ] \
#   && [ -n "$PS1" ] \
#   && [[ "$TERM_PROGRAM" != "vscode" ]]; then
#   tmux attach -t main || tmux new -s main
# fi

# Clipboard command differs per platform (macOS vs Wayland vs X11)
if command -v pbcopy &>/dev/null; then
  export CLIPBOARD_CMD="pbcopy"
elif command -v wl-copy &>/dev/null; then
  export CLIPBOARD_CMD="wl-copy"
elif command -v xclip &>/dev/null; then
  export CLIPBOARD_CMD="xclip -selection clipboard"
fi

# FZF
if command -v fzf &>/dev/null; then
  source <(fzf --zsh)

  export FZF_CTRL_T_OPTS="
    --walker-skip .git,node_modules,target
    --preview 'bat -n --color=always {}'
    --bind 'ctrl-/:change-preview-window(down|hidden|)'"

  export FZF_CTRL_R_OPTS="
    --bind 'ctrl-y:execute-silent(echo -n {2..} | ${CLIPBOARD_CMD:-cat})+abort'
    --color header:italic
    --header 'Press CTRL-Y to copy command into clipboard'"

  export FZF_ALT_C_OPTS="
    --walker-skip .git,node_modules,target
    --preview 'tree -C {}'"
fi

# Aliases
[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases

# Machine-specific overrides (stowed from hosts/<hostname>/)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Private, per-machine settings that must never be committed: tokens, work
# endpoints, employer-specific aliases. A plain file in $HOME — the repo has
# no copy of it, so there is nothing to stow and nothing to leak.
[[ -f ~/.zshrc.private ]] && source ~/.zshrc.private

# Starship prompt
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# Zoxide
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

uptime

# Plugins — sourced last. Paths differ per OS (brew vs Arch packages), so
# source the first one that exists. Order matters: syntax highlighting, then
# autosuggestions, then history-substring-search.
_source_plugin() {
  local name="$1" f
  for f in \
    "/opt/homebrew/share/$name/$name.zsh" \
    "/opt/homebrew/opt/$name/share/$name/$name.zsh" \
    "/usr/share/zsh/plugins/$name/$name.zsh"
  do
    if [[ -f "$f" ]]; then
      source "$f"
      return 0
    fi
  done
  return 1
}

_source_plugin zsh-syntax-highlighting
_source_plugin zsh-autosuggestions

# Type part of a command, then up/down (or k/j in vi normal mode) cycles
# through matching history.
if _source_plugin zsh-history-substring-search; then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
fi

unfunction _source_plugin
