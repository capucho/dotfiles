# dotfiles

Personal configuration managed with [GNU Stow](https://www.gnu.org/software/stow/). One repo, two install scripts, fully-ready dev machine.

## Machines

| Hostname | OS | Role |
|---|---|---|
| `Henriques-MacBook-Air` | macOS | Primary dev machine |
| `omarchy` | Omarchy (Arch) | Linux dev machine |
| `optiplex` | Debian | Homelab server (SSH only) |

## Prerequisites

- `git` (only external dependency — everything else is installed by the script)
- On Omarchy: a working Omarchy install

## Quick start

```sh
git clone git@github.com:capucho/dotfiles.git ~/dotfiles
cd ~/dotfiles

# macOS
bash install-mac.sh

# Omarchy
bash install-omarchy.sh
```

The scripts are **idempotent** — safe to re-run after pulling updates.

## What gets installed

| Tool | Mac | Omarchy | Notes |
|---|---|---|---|
| zsh | ✓ | ✓ | set as default shell |
| git + gh | ✓ | ✓ | GitHub CLI |
| neovim | ✓ | ✓ | LazyVim, Go/Rust/TS/Python/Markdown support |
| tmux | ✓ | ✓ | catppuccin mocha, TPM auto-bootstrapped |
| ghostty | ✓ | ✓ | set as default terminal on Omarchy |
| starship | ✓ | ✓ | prompt |
| herdr | ✓ | ✓ | agent multiplexer |
| fnm | ✓ | ✓ | Node version manager; installs LTS |
| pnpm | ✓ | ✓ | installed after Node |
| claude-code | ✓ | ✓ | `npm install -g @anthropic-ai/claude-code` |
| Go | ✓ | ✓ | latest via brew/pacman |
| Rust | ✓ | ✓ | rustup, stable + rust-analyzer |
| uv | ✓ | ✓ | Python tooling |
| mise | ✓ | ✓ | per-project version pinning only |
| fzf + zoxide + bat | ✓ | ✓ | shell quality-of-life |
| zsh-syntax-highlighting | ✓ | ✓ | |
| hugo | ✓ | ✓ | static site generator |
| terraform | ✓ | ✓ | IaC |
| docker | note | ✓ | Mac: install Docker Desktop manually |

## Post-install checklist

After running the install script:

- [ ] **Generate SSH keys** (see SSH section below)
- [ ] **Mac only**: install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [ ] **Connect herdr + Claude**: open herdr → connect the Claude integration
- [ ] **Restart your terminal** (or `source ~/.zshrc`)
- [ ] **Omarchy only**: log out and back in (shell change + docker group)

## SSH key management

Two separate keys — one for git hosting, one for machine access:

```sh
# Git hosting (GitHub, GitLab)
dotfiles-gen-git-key your@email.com
# generates ~/.ssh/id_ed25519_git
# prints public key to add to your git host

# Machine-to-machine (ssh-copy-id)
dotfiles-gen-machine-key
# generates ~/.ssh/id_ed25519_machines
# prints ssh-copy-id usage
```

Copy a machine key to a remote host:

```sh
ssh-copy-id -i ~/.ssh/id_ed25519_machines.pub user@192.168.0.115
```

## Updating

```sh
cd ~/dotfiles
git pull
stow --restow --target="$HOME" <changed-package>
```

Or re-run the install script — it's idempotent.

## Repo structure

```
dotfiles/
├── install-mac.sh        # macOS bootstrap
├── install-omarchy.sh    # Omarchy bootstrap
├── CLAUDE.md             # agent maintenance instructions
├── zsh/                  # .zshrc, .zsh_aliases (SSH helpers + worktree functions)
├── nvim/                 # LazyVim config; theme.lua Mac-only
├── tmux/                 # catppuccin mocha, TPM
├── ghostty/              # terminal config
├── starship/             # prompt config
├── git/                  # global git config + gitignore
├── ssh/                  # ~/.ssh/config template (no private keys)
├── claude/               # skills/, agents/, CLAUDE.md, settings.json
├── herdr/                # herdr config (no session data)
├── aws/                  # config.template only (no credentials)
├── mise/                 # stub config for per-project use
└── hosts/
    ├── Henriques-MacBook-Air/   # Mac-specific overrides
    ├── omarchy/                 # Omarchy-specific overrides
    └── optiplex/                # Homelab server overrides
```

## What is NOT in this repo

- SSH private keys
- AWS credentials or live `~/.aws/config`
- Herdr session data
- Claude cache, history, sessions
- `.env` files

## Adding a new tool

1. Create a stow package: `mkdir -p <tool>/.config/<tool>/`
2. Add the install command to both `install-mac.sh` and `install-omarchy.sh`
3. Add `stow <tool>` to both scripts
4. Add a row to the tools table above

See `CLAUDE.md` for full agent instructions.
