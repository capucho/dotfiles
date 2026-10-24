export EDITOR="nvim"
export VISUAL="nvim"

# Local binaries (fnm, uv and other installers land here on Linux)
export PATH="$HOME/.local/bin:$PATH"

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

# Machine-specific overrides
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Starship prompt
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# Zoxide
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# Syntax highlighting — must be sourced last. Path differs per OS.
for _zsh_hl in \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /opt/homebrew/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
do
  if [[ -f "$_zsh_hl" ]]; then
    source "$_zsh_hl"
    break
  fi
done
unset _zsh_hl
