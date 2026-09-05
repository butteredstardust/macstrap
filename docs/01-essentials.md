# 01 — Essentials

Three things must exist before anything else works.

| Layer | What | Why it is first |
|---|---|---|
| Xcode Command Line Tools | `clang`, `make`, `git`, SDK headers | Homebrew refuses to install without it. So do most native npm and cargo builds |
| Homebrew | package manager | everything else here installs through it |
| zsh | login shell | the macOS default. All shell config here assumes it |

## Command Line Tools

```bash
xcode-select --install     # opens a GUI installer, runs asynchronously
xcode-select -p            # succeeds once the install has finished
```

The installer command returns before the install finishes. Poll `xcode-select -p` instead of
trusting the exit code. `scripts/preflight.sh` does exactly that.

Full Xcode is only needed for building iOS/macOS apps. After installing it, point the toolchain at
it:

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
| Apple Silicon | `/opt/homebrew` | not on the default `PATH`. `brew shellenv` adds it |
| Intel | `/usr/local` | already on `PATH` |

The installer does **not** wire up your shell. `~/.zprofile` does:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Put this in `.zprofile`, not `.zshrc`. It then runs once per login, and everything spawned from that
session inherits `PATH`, `MANPATH` and the `HOMEBREW_*` variables. In `.zshrc` it re-runs for every
interactive shell and stacks duplicate `PATH` entries.

Turn off the per-command analytics ping:

```bash
brew analytics off
```

## What macOS already ships

| Preinstalled | Version reality |
|---|---|
| `git` | old. The Homebrew build shadows it once `PATH` is set, which is intended |
| `python3` | system-managed. **Never** `pip install` into it. Use `uv` |
| `ruby` | system-managed, deprecated for user scripts |
| `bash` | 3.2, held back by licensing. Scripts needing `bash 4+` need the Homebrew build |
| `zsh` | current enough. No reason to replace it |

## Encryption

These scripts leave FileVault alone, because it generates a recovery key you must record yourself.
Turn it on by hand: **System Settings → Privacy & Security → FileVault**. `doctor.sh` warns while it
is off.
