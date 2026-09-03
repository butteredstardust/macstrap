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

Opinionated on purpose. It is not a dotfiles framework and there is nothing to configure before it
works — clone, run, get a working machine. Every choice is written down with its reasoning, so you
can disagree with a specific one instead of forking the whole thing.

### Requirements

macOS 14+ on Apple Silicon or Intel. Nothing is installed as root — the scripts refuse to run under
`sudo` and ask for it only at the moments that genuinely need it.

---

## What you get

| Area          | What it sets up                                                                  |
| ------------- | -------------------------------------------------------------------------------- |
| **Shell**     | zsh, no framework — starship prompt, three plugins, tuned completion and history  |
| **Terminal**  | Ghostty with a Nerd Font, one deduplicated config                                |
| **CLI**       | `eza` `bat` `fd` `ripgrep` `dust` `procs` `delta` `jq` `gh` `htop`               |
| **Languages** | rustup, node + pnpm + bun, uv for Python                                         |
| **Editors**   | VS Code, settings and extension list version-controlled                          |
| **System**    | Finder, keyboard, Dock and screenshot defaults — opt-in, all reversible          |
| **Upkeep**    | `doctor.sh` health check, drift detection against the Brewfiles                  |

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

Every step is idempotent. Running twice is safe; the second run is mostly no-ops.

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
  languages.sh            rust toolchain, corepack, uv tools
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
| [02 — CLI tools](docs/02-cli-tools.md)              | modern replacements, and what was deliberately left out         |
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

**No framework.** oh-my-zsh is a lot of machinery to source three plugins. `.zshrc` does it in three
lines and starts in a fraction of the time.

**Symlinks, not copies.** Editing `~/.zshrc` *is* editing the repo, so `git status` shows drift the
moment it appears. The exception is anything holding an identity or a secret — `~/.gitconfig` is
rendered from a template, and `~/.zshrc.local` / `~/.zshenv.local` are yours and untracked.

**The machine gets a manager, the project gets a version.** Global installs are for tools you invoke
outside a project. Versions belong in `rust-toolchain.toml`, `.nvmrc`, `uv.lock`.

**Idempotent and reversible.** Nothing is deleted. Replaced files become `<name>.bak-<timestamp>`.
Every `defaults write` undoes with one `defaults delete`.

**Explain the gotcha, not the command.** `brew install eza` needs no documentation. Why
`zsh-syntax-highlighting` must be sourced last, why a `PATH` assignment breaks `bun run`, and why
Ghostty silently ignores your first `window-padding-x` — those cost hours to rediscover.

**Cruft is not configuration.** This was distilled from a machine with a leaked transitive
dependency pinned in `brew leaves`, three overlapping Docker installs, four editor AI extensions
racing for the same inline-completion slot, a `conda init` block costing 150ms of every shell, and a
terminal asking for a font that was never installed. None of it was a decision; all of it was
sediment. Every entry here had to justify itself.

The inverse also applies: several terminal AI agents *are* kept, because separate binaries you
invoke deliberately do not conflict the way editor extensions do. Duplication is only cruft when the
copies compete.

---

## Privacy

This repo is public and contains no identifying information. If you fork it, keep it that way:

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

Out of scope for now. The structure leaves room — a `windows/` directory with `winget` manifests, a
PowerShell profile and Windows Terminal settings, sharing `docs/` where the reasoning is
platform-independent. Contributions welcome.

---

## Credits

Structure inspired by [xmlking's macOS Setup Guide](https://xmlking.gitbook.io/macos-setup/).
The specific choices, and the gotchas, are from running this setup daily.

---

## License

MIT. Take what is useful, ignore the rest.
