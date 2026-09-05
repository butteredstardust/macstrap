<div align="center">

<img src="assets/macstrap.png" alt="" width="128" height="128">

# macstrap

**A reproducible macOS development machine.**
**Scripts to provision it, docs explaining every decision.**

[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Platform](https://img.shields.io/badge/platform-Apple%20Silicon%20%7C%20Intel-lightgrey?style=for-the-badge)](#requirements)
[![Shell](https://img.shields.io/badge/shell-zsh-4EAA25?style=for-the-badge&logo=zsh&logoColor=white)](dotfiles/zsh/zshrc)
[![Homebrew](https://img.shields.io/badge/Homebrew-bundle-FBB040?style=for-the-badge&logo=homebrew&logoColor=white)](https://brew.sh)

</div>

---

## Quick start

```bash
git clone https://github.com/<you>/macstrap.git ~/Dev/macstrap
cd ~/Dev/macstrap
./bootstrap.sh --dry-run    # read what it will do
./bootstrap.sh
```

Opinionated on purpose. This is not a dotfiles framework. Nothing needs configuring before it works:
clone, run, get a working machine. Every choice carries its reasoning, so you can disagree with one
decision instead of forking the whole repo.

### Requirements

macOS 14+ on Apple Silicon or Intel. Nothing installs as root. The scripts refuse to run under
`sudo` and ask for it only at the steps that need it.

---

## What you get

| Area          | What it sets up                                                                  |
| ------------- | -------------------------------------------------------------------------------- |
| **Shell**     | zsh, no framework. starship prompt, three plugins, tuned completion and history   |
| **Terminal**  | Ghostty with a Nerd Font. One config, each key declared once                      |
| **CLI**       | `eza` `bat` `fd` `ripgrep` `dust` `procs` `delta` `jq` `gh` `htop`               |
| **Languages** | rustup, node + pnpm + bun, uv for Python                                         |
| **Editors**   | VS Code. Settings and extension list tracked in git                              |
| **System**    | Finder, keyboard, Dock and screenshot defaults. Opt-in, all reversible           |
| **Upkeep**    | `doctor.sh` health check. Drift report against the Brewfiles                     |

---

## Usage

```bash
./bootstrap.sh                        # preflight → homebrew → packages → dotfiles → languages → editors
./bootstrap.sh --dry-run              # print every action, change nothing
./bootstrap.sh --yes                  # never prompt
./bootstrap.sh --with-optional        # also Brewfile.optional
./bootstrap.sh --with-macos-defaults  # also system preferences (read docs/09 first)
./bootstrap.sh --only dotfiles,editors
./bootstrap.sh --list

scripts/doctor.sh                     # verify the result; changes nothing
scripts/test.sh                       # checks the repo itself: lint, privacy, fresh-machine dry run
```

Every step is idempotent. Run it twice safely. The second run is mostly no-ops.

---

## Layout

```
bootstrap.sh              entry point, step runner
Brewfile                  CLI tools used daily
Brewfile.apps             GUI applications
Brewfile.optional         taste, media, "might want"
scripts/
  lib.sh                  logging, dry-run, idempotent symlinks
  preflight.sh            CLT, Rosetta, guards
  homebrew.sh             install brew, disable analytics
  packages.sh             brew bundle + drift report
  dotfiles.sh             symlink dotfiles, render git identity
  languages.sh            rust toolchain, node check, uv tools
  editors.sh              VS Code settings + extensions, Claude Code
  macos-defaults.sh       system preferences (opt-in)
  doctor.sh               read-only health check
  test.sh                 lint, privacy scan, simulated fresh-machine run
dotfiles/                 the actual config, symlinked into ~
docs/                     why each decision was made
```

---

## Docs

| Doc                                                 | Covers                                                          |
| --------------------------------------------------- | --------------------------------------------------------------- |
| [01 — Essentials](docs/01-essentials.md)            | Command Line Tools, Homebrew, what macOS already ships          |
| [02 — CLI tools](docs/02-cli-tools.md)              | modern replacements, and what stays out on purpose              |
| [03 — Shell](docs/03-shell.md)                      | which zsh file runs when, load order, `PATH` without duplicates |
| [04 — Terminal](docs/04-terminal.md)                | Ghostty config, Nerd Fonts, terminfo over SSH                   |
| [05 — Languages](docs/05-languages.md)              | rustup, node, uv, and installing exactly one Docker             |
| [06 — Apps](docs/06-apps.md)                        | the three Brewfiles and why they are split                      |
| [07 — Editors](docs/07-editors.md)                  | VS Code settings, extensions, and what must never go in them    |
| [08 — Git & GitHub](docs/08-git-github.md)          | identity, noreply email, SSH keys, signing                      |
| [09 — macOS defaults](docs/09-macos-defaults.md)    | every `defaults write`, and how to reverse it                   |
| [10 — Maintenance](docs/10-maintenance.md)          | weekly routine, catching drift, migrating                       |
| [11 — Troubleshooting](docs/11-troubleshooting.md)  | symptom → cause → fix                                           |

---

## Principles

**No framework.** oh-my-zsh is a lot of machinery to source three plugins. `.zshrc` sources them in
three lines. It also starts in a fraction of the time.

**Symlinks, not copies.** Editing `~/.zshrc` *is* editing the repo, so `git status` shows drift the
moment it appears. Files holding an identity or a secret are the exception. `~/.gitconfig` renders
from a template. `~/.zshrc.local` and `~/.zshenv.local` are yours, and untracked.

**The machine gets a manager, the project gets a version.** Install globally only what you invoke
outside a project. Pin versions in `rust-toolchain.toml`, `.nvmrc`, `uv.lock`.

**Idempotent and reversible.** Nothing is removed. Replaced files become `<name>.bak-<timestamp>`.
Every `defaults write` reverses with one `defaults delete`.

**Explain the gotcha, not the command.** `brew install eza` needs no documentation. The docs cover
what costs hours to rediscover: why `zsh-syntax-highlighting` must be sourced last, why a `PATH`
assignment breaks `bun run`, why Ghostty ignores your first `window-padding-x`.

**Cruft is not configuration.** Every package, extension and setting here justifies itself in the
docs. One owner per tool, one extension per job, one Docker.

Duplication is only cruft when the copies compete. Several terminal AI agents coexist here, because
separate binaries you invoke deliberately never race each other. Two inline-completion providers do.

---

## Privacy

This repo is public and holds no identifying information. Keep your fork that way:

| Never commit                                     | Where it goes                             |
| ------------------------------------------------ | ----------------------------------------- |
| name, email, GitHub handle                       | `~/.gitconfig`, rendered from a template  |
| API tokens, auth headers, local service URLs     | `~/.zshrc.local`, `~/.zshenv.local`       |
| signing keys                                     | a file outside the repo, read by `.zshenv.local` |
| hostnames, LAN IPs, internal endpoints           | not here at all                           |
| `~/.ssh`, `~/.config/gh/hosts.yml`, `~/.claude/` | nowhere — regenerate per machine          |

`.gitignore` covers `*.local`, `secrets/`, and the rendered `dotfiles/git/gitconfig`. Before your
first push:

```bash
git log -p | grep -iE '(api[_-]?key|token|secret|password|@gmail|@users\.noreply)'
```

---

## Windows

Out of scope for now. The structure leaves room for it: a `windows/` directory with `winget`
manifests, a PowerShell profile and Windows Terminal settings. It would share `docs/` wherever the
reasoning is platform-independent. Contributions welcome.

---

## Credits

Structure inspired by [xmlking's macOS Setup Guide](https://xmlking.gitbook.io/macos-setup/).

---

## License

MIT. Take what is useful, ignore the rest.
