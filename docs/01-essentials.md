# 01 — Essentials

The three things that must exist before anything else works.

| Layer | What | Why it is first |
|---|---|---|
| Xcode Command Line Tools | `clang`, `make`, `git`, SDK headers | Homebrew refuses to install without it; so do most native npm and cargo builds |
| Homebrew | package manager | everything else in this repo is installed through it |
| zsh | login shell | macOS default since Catalina; all shell config here assumes it |

## Command Line Tools

```bash
xcode-select --install     # opens a GUI installer, runs asynchronously
xcode-select -p            # succeeds once it is actually done
```

The installer returning is **not** the same as it being finished. `scripts/preflight.sh` polls
`xcode-select -p` rather than trusting the exit code.

You do not need full Xcode unless you are building iOS/macOS apps. If you do install it, point the
toolchain at it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

## Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

| Arch | Prefix | Notes |
|---|---|---|
| Apple Silicon | `/opt/homebrew` | not on the default `PATH` — `brew shellenv` puts it there |
| Intel | `/usr/local` | already on `PATH` |

The installer does **not** wire up your shell. That is `~/.zprofile`:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

In `.zprofile`, not `.zshrc`: it runs once per login and everything spawned from that session
inherits `PATH`, `MANPATH` and the `HOMEBREW_*` variables. Putting it in `.zshrc` re-runs it for
every interactive shell and stacks duplicate `PATH` entries.

Turn off the per-command analytics ping:

```bash
brew analytics off
```

## What macOS already ships

| Preinstalled | Version reality |
|---|---|
| `git` | old, and shadowed by the Homebrew one once `PATH` is set — that is intended |
| `python3` | system-managed; **never** `pip install` into it. Use `uv` |
| `ruby` | system-managed, deprecated for user scripts |
| `bash` | 3.2, from 2007, for licensing reasons. Scripts wanting `bash 4+` need the brew one |
| `zsh` | current enough; no reason to replace it |

## Encryption

FileVault is not enabled by these scripts because it generates a recovery key you must record
yourself. Turn it on manually: **System Settings → Privacy & Security → FileVault**. `doctor.sh`
warns if it is off.
