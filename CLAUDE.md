# Dotfiles — Agent Instructions

## Repo overview

Single config repo managed with GNU Stow. Each top-level directory is a stow package that mirrors the `$HOME` directory structure. `install-mac.sh` and `install-omarchy.sh` bootstrap a fresh machine end-to-end.

## Stow conventions

- Each package dir mirrors `$HOME`. Example: `tmux/.config/tmux/tmux.conf` stows to `~/.config/tmux/tmux.conf`.
- Run stow from `~/dotfiles/`: `stow --restow --target="$HOME" <package>`
- `hosts/<hostname>/` contains machine-specific overrides, stowed the same way.
- `nvim/lua/plugins/theme.lua` is Mac-only — stowed manually by `install-mac.sh`, not by `install-omarchy.sh`.

## Adding a new tool

1. Create `<tool>/.config/<tool>/` (or wherever the tool reads its config).
2. Add `brew install <tool>` to `install-mac.sh` and `omarchy pkg add <tool>` to `install-omarchy.sh`.
3. Add `stow <tool>` to both install scripts.
4. Document in README.md under the tools table.

## Platform rules

- **Mac**: use `brew install`. Never `sudo apt` or `pacman`.
- **Omarchy**: use `omarchy pkg add` — never raw `pacman -S` or `yay`. This respects Omarchy's update layer.
- **Omarchy AUR**: if a package isn't in official repos, check with the user before using AUR directly.

## What never to commit

- SSH private keys (`id_*` without `.pub`)
- AWS credentials or live `~/.aws/config` (template only)
- Herdr session/socket files (`session.json`, `*.sock`, `*.log`)
- Claude state dirs (`cache/`, `sessions/`, `history.jsonl`, `projects/`, etc.)
- The `claude/.claude/skills/synced/` directory (marketplace-managed)
- `.env` files of any kind

## Neovim theme split

- `nvim/.config/nvim/lua/plugins/theme.lua` sets oxocarbon colorscheme.
- **Mac only** — `install-mac.sh` stows it explicitly.
- **Omarchy** — `install-omarchy.sh` removes this symlink so Omarchy's theme system controls the colorscheme.
- Never set a colorscheme in `main-config.lua` or any shared plugin file.

## Per-project version pinning

Use `.mise.toml` at project root. Global runtimes are managed by specialized tools (fnm, rustup, brew/pacman for Go) — not by mise globally.

## Updating the repo

```sh
cd ~/dotfiles
git pull
stow --restow --target="$HOME" <changed-package>
```

The install scripts are idempotent — safe to re-run after pulling changes.
