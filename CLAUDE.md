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

### Always getting zsh

Three independent layers, because any one alone leaves a gap:

1. `command = zsh` in the Ghostty config — Ghostty launches zsh directly rather
   than trusting `$SHELL`/passwd. Bare name so PATH resolves it per platform.
2. `export SHELL` in `.zshrc` — `$SHELL` reports the passwd entry, not the
   running shell, so tmux (which derives `default-shell` from it) would open
   bash panes inside a zsh terminal. Corrected to the running zsh.
3. `chsh -s $(command -v zsh)` in the install script — fixes the login shell
   for tty and ssh sessions, which never go through Ghostty. Needs a logout.

Do not drop to only `chsh`: it requires a full logout, so a fresh Omarchy box
would run bash in the meantime.
- Ghostty: the shared `config` holds cross-platform keys only and ends with
  `config-file = ?~/.config/ghostty/os-local`. Machine-specific keys live in
  `hosts/<hostname>/.config/ghostty/os-local`. `macos-option-as-alt` and a
  hardcoded `theme` are macOS-only — on Linux they are unknown fields and
  Ghostty prints an error at startup. The shared config also optionally
  includes Omarchy's active theme symlink so Omarchy keeps driving the theme.
  A `?` prefix on a `config-file` path makes a missing file silently ignored.

## Never use a tool without verifying it exists

Installing a package is not proof the tool works. Both install scripts follow
this discipline and any change must keep it:

- `has <bin>` — the only way to test for a command.
- `require "<bin>|<how to get it>"` — hard gate before a phase that cannot work
  without the tool. Aborts with an actionable message. Used at preflight
  (`git`, `curl`, `pacman`/`brew`) and before the stow phase (`stow`).
- `install_pkg <pkg> [bin]` / `brew_install <kind> <pkg> [bin]` — install, then
  **verify the binary appeared**. A failure is recorded in `$FAILED` and
  reported in the summary; it never kills the run.
- `install_any <bin> <pkg>...` (Omarchy) — for tools whose package name differs
  between repos. `gh` is `github-cli` on Arch; this resolves it.

Dependent phases must be guarded by the tool they need, not assumed:
`npm` only exists if the Node install succeeded, so the pnpm/claude-code step
checks `has npm` first. Same for `systemctl`, `sudo`, `chsh`, `rustup`.

The scripts use `set -uo pipefail`, **not** `set -e`: one failed package should
report itself and let the rest of the setup finish, rather than aborting
half-configured.

## Adding a new tool

1. Create `<tool>/.config/<tool>/` (or wherever the tool reads its config).
2. Add an install line to both scripts, **always passing the binary to verify**:
   - `install-mac.sh`: `brew_install formula <pkg> <bin>` (or `cask`)
   - `install-omarchy.sh`: `install_pkg <pkg> <bin>`, or `install_any <bin> <pkg-a> <pkg-b>`
     when the package name differs between repos.
   Omit the binary only for packages that ship no executable (e.g.
   `zsh-syntax-highlighting`).
3. Add the package to the stow `for` loop in both scripts.
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
