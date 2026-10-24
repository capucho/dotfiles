export EDITOR="nvim"
export VISUAL="nvim"

# fnm — Node version management
export FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
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

# Local binaries
export PATH="$HOME/.local/bin:$PATH"

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

# FZF
source <(fzf --zsh)

export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

export FZF_CTRL_R_OPTS="
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"

export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"

# Aliases
[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases

# Machine-specific overrides
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Starship prompt
eval "$(starship init zsh)"

# Zoxide
eval "$(zoxide init zsh)"

# Syntax highlighting — path differs per OS
if [[ -f /opt/homebrew/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
