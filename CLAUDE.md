# Dotfiles — Agent Instructions

## Repo overview

Single config repo managed with GNU Stow. Each top-level directory is a stow package that mirrors the `$HOME` directory structure. `install-mac.sh` and `install-omarchy.sh` bootstrap a fresh machine end-to-end.

## Stow conventions

- Each package dir mirrors `$HOME`. Example: `tmux/.config/tmux/tmux.conf` stows to `~/.config/tmux/tmux.conf`.
- Run stow from `~/dotfiles/`: `stow --restow --target="$HOME" <package>`
- `hosts/<hostname>/` contains machine-specific overrides, stowed the same way.
- Host lookup uses `hostname -s`. On macOS plain `hostname` returns
  `Henriques-MacBook-Air.local` and will not match the `hosts/` directory name.

### Tree folding — read before adding a package

If a target directory does not exist, stow creates **one symlink for the whole
directory** instead of linking each file. Anything written there at runtime then
lands inside this repo.

The install scripts therefore `mkdir -p` these before stowing, so they stay real
directories and only the tracked files are linked:

`~/.ssh`, `~/.claude`, `~/.config/git`, `~/.config/herdr`, `~/.config/tmux`

Without that, SSH private keys, `git config.local`, herdr sockets, Claude's
cache/history and TPM's cloned plugins all end up inside the repo.

**When adding a package, ask: does anything write to this directory at runtime?**
If yes, add it to the `mkdir -p` list in both install scripts.

Directories that are safe to fold (config only, no runtime writes): `~/.config/nvim`,
`~/.config/ghostty`, `~/.config/mise`.

### Platform-specific config

Never branch on platform by stowing different files — stow folding makes that
unreliable. Branch **inside** the config file instead:

- Neovim: `lua/plugins/theme.lua` returns `{}` unless `vim.fn.has("mac")`, so
  Omarchy's theme system keeps control of the colorscheme.
- zsh: guard on `command -v <tool>`, never on a hardcoded install path
  (brew and the Linux installers use different prefixes).
- SSH: `IgnoreUnknown UseKeychain` — that keyword is macOS-only and Linux
  OpenSSH aborts on unknown keywords.
- Clipboard: `$CLIPBOARD_CMD` resolves to `pbcopy` / `wl-copy` / `xclip`.

## Adding a new tool

1. Create `<tool>/.config/<tool>/` (or wherever the tool reads its config).
2. Add it to `BREW_FORMULAE` (or `BREW_CASKS`) in `install-mac.sh` and to
   `PACKAGES` in `install-omarchy.sh`. Package names differ: `gh` on Homebrew
   is `github-cli` on Arch.
3. Add the package to the `PACKAGES` stow list in both scripts.
4. If anything writes to its config dir at runtime, add that dir to the
   `mkdir -p` list in both scripts (see Tree folding above).
5. Document it in the README tools table.

## Platform rules

- **Mac**: use `brew install`. Check formulae with `brew list --formula` and
  casks with `brew list --cask` — ghostty is a **cask**, so a plain
  `brew list ghostty` check never matches.
- **Omarchy**: use `omarchy pkg add` — never raw `pacman -S`, `paru` or `yay`.
  This keeps Omarchy's update channel authoritative. `pacman -Q` is fine for
  *querying* whether something is installed.
- **Omarchy AUR**: if a package isn't in the official repos, check with the user
  before reaching for the AUR.

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
