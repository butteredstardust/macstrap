# 05 — Language toolchains

Principle: **the machine gets a manager, the project gets a version.** Install globally only what you
invoke outside a project directory. Pin everything else in the project repo.

| Language | Manager | Project pin |
|---|---|---|
| Rust | `rustup` | `rust-toolchain.toml` |
| Node | Homebrew `node` + `pnpm` | `packageManager` in `package.json`. Recorded, not enforced (see below) |
| Python | `uv` | `pyproject.toml` + `uv.lock` |

## Rust

Install the `rustup` formula, **not** `rust`. The `rust` formula pins one compiler version, with no
way to add targets or switch channels.

```bash
brew install rustup
rustup default stable
rustup component add rust-analyzer clippy rustfmt
```

**Two gotchas. Either one alone leaves you with a broken Rust:**

1. **The formula is keg-only.** It conflicts with the `rust` formula, so Homebrew does not symlink
   its binaries into `bin/`. One exception makes the failure confusing: `rustup` itself *is*
   symlinked, while `cargo`, `rustc` and `rustfmt` are not. The symptom is `rustup` answering
   normally while `cargo` is `command not found`. That reads like a broken toolchain rather than a
   missing `PATH` entry. All of them live in `$(brew --prefix)/opt/rustup/bin`, which `.zshenv`
   adds:

   ```zsh
   export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
   ```

   The path is hardcoded. Calling `brew --prefix rustup` would add ~100ms to every shell start.

   **Put it in `.zshenv`, not `.zshrc`.** Only interactive shells read `.zshrc`, and a build script
   running `zsh -c 'cargo build'` is not one. From `.zshrc`, Rust works when you type it and
   disappears under any tool that shells out.

2. **The formula installs the manager, not a toolchain.** Every `cargo` invocation then fails with
   `no default toolchain configured`. Run `rustup default stable` once.

`scripts/languages.sh` handles both. It warns when `rustup` is missing from `PATH` instead of
skipping the step silently.

### Do not also run the rustup.rs installer

`curl https://sh.rustup.rs | sh` is the instruction on rust-lang.org, and it works. Running it *as
well as* the formula leaves two independently-versioned copies of rustup on one machine. The upstream
copy writes shims to `~/.cargo/bin`, plus a `~/.cargo/env` that **prepends** that directory ahead of
Homebrew's.

The split does not announce itself. Both copies dispatch to the same toolchains in `~/.rustup`, so
`cargo build` keeps working and `rustup --version` looks right. It surfaces at the edges: `rustup`
resolves to Homebrew while `cargo` resolves to `~/.cargo/bin`. Different startup files add the two
directories, and only one of those files is read by non-interactive shells.

Pick one owner. Here the owner is Homebrew, so:

```bash
cargo install --list        # confirm no user-installed crates live there first
rm ~/.cargo/bin/*           # these are only rustup's shims
```

Keep `~/.rustup`, the toolchains, ~1.4GB. Removing it means re-downloading them. Keep
`~/.cargo/registry`, the dependency cache. Do **not** run `rustup self uninstall`: it removes both.

`~/.cargo/bin` stays on `PATH`, because `cargo install` still writes there. `.zshenv` does more than
append missing entries. It removes every occurrence of both Rust directories, then puts the Homebrew
rustup directory first and `~/.cargo/bin` last. Appending alone cannot fix a bad order inherited from
a parent process.

```bash
rustup update
rustup target add aarch64-apple-darwin x86_64-apple-darwin   # universal binaries
cargo clippy -- -D warnings
```

## Node

```bash
brew install node pnpm
```

**Exactly one installer may own `pnpm` and `pnpx`.** Homebrew declares its `pnpm` and `corepack`
formulae mutually conflicting for this reason: they install the same two binaries. `npm install -g`
is worse. npm's global bin directory overwrites Homebrew's symlinks, then removes them on uninstall,
leaving `pnpm: command not found` with the formula still installed. See
[docs/11](11-troubleshooting.md).

Here the owner is **the Homebrew `pnpm` formula**. Corepack stays uninstalled.

Corepack sounds like the more principled choice. It reads `packageManager` from `package.json` and
fetches that exact version. Two things rule it out:

- It supports **npm, pnpm and yarn** only. It cannot honour a `packageManager` field pinned to `bun`.
- It resolves versions over the network on first use of a project. A global pnpm just runs.

That trade flips once you work across repos that pin pnpm and disagree on the version. In that case,
install `corepack` **instead of** `pnpm`, never alongside it:

```bash
brew uninstall pnpm && brew install corepack
```

Either way the rule holds: one owner, installed by one package manager. Getting this wrong produces
no conflict message. It produces a working `pnpm` that disappears weeks later, when you uninstall the
other owner.

| Manager | Use |
|---|---|
| `pnpm` | default. Content-addressed store, strict by default, fast |
| `bun` | runtime, test runner and bundler. Also a fast installer |
| `npm` | when a project ships an `npm`-shaped lockfile |
| `nvm` | only when a project pins an old Node. It costs ~200ms of shell startup, so it lives in `Brewfile.optional` |

**Never install project dependencies globally.** Editor tooling picks up a global `typescript` that
is a major version ahead of the project's. You then get errors that do not reproduce in CI.

## Python

`uv` replaces `pyenv`, `pipx`, `virtualenv` and `pip-tools`. One tool, written in Rust, fast enough
that nothing else earns its place.

```bash
uv python install 3.13      # manage interpreters
uv init && uv add requests  # project + deps, writes uv.lock
uv run script.py            # runs in the project env, no activation
uv tool install ruff        # global CLI in its own isolated venv
```

Install `uv` from Homebrew (`brew "uv"`), not from `astral.sh/uv/install.sh`. The standalone
installer sets the same trap as rustup. It puts a self-updating binary in `~/.local/bin`, ahead of
Homebrew's copy on `PATH`. `brew upgrade uv` then appears to do nothing, and `uv --version` keeps
reporting the older number. With both present, remove the standalone one:

```bash
which -a uv                 # two hits means two installs
rm ~/.local/bin/uv ~/.local/bin/uvx
```

Nothing is lost. Tool environments live in `~/.local/share/uv/tools`, interpreters in
`~/.local/share/uv/python`. Both are shared. The shims in `~/.local/bin` point straight into those
venvs, not at the `uv` binary. `~/.local/bin` stays on `PATH` for that reason: `uv tool` installs
there.

### When `uv tool list` says "environment not found"

```
warning: Tool `pyright` environment not found (run `uv tool install pyright --reinstall`)
```

The record survived, the venv did not. An unrelated cleanup removed the interpreter it was built
against. The shim in `~/.local/bin` still exists and fails at exec time with `bad interpreter`. Any
check that only tests whether the command exists misses this. Reinstall the tool as the warning says,
or run `uv tool uninstall <name>`. Run `uv tool list` after any Python housekeeping — nothing else
reports this state.

### Migrating off pipx and conda

`uv` takes over from both:

```bash
pipx list --short                       # what you would lose
uv tool install --force <each-one>      # --force: pipx's shims are still in ~/.local/bin
brew uninstall pipx                     # only after verifying each tool still runs
```

`--force` is required. Both tools write executables to `~/.local/bin`, so `uv tool install` stops
with `Executables already exist` until it may overwrite pipx's shims. Verify each tool with
`<tool> --version` *before* uninstalling pipx. The shims and the real installs share one directory.

For conda, check `conda env list` first. If `base` is the only environment, nothing uses it and the
cask can go. Removing it also lets you delete the `conda init` block from `.zshrc`, worth roughly
150ms on every shell you open. `brew uninstall --cask miniforge` shells out to `sudo`, so run it in a
real terminal.

**Never `pip install` into the system Python.** macOS ships `/usr/bin/python3` for its own use.
Writing to it breaks OS tooling, and system updates wipe it. Recent versions refuse with
`externally-managed-environment`.

Globally installed via `uv tool`:

| Tool | Role |
|---|---|
| `ruff` | linter and formatter. Replaces flake8, isort and black |
| `pyright` | type checker. Same engine as VS Code's Pylance |

## Containers

**Install exactly one Docker.** The `docker` formula and the `docker` and `docker-desktop` casks each
put a `docker` binary on `PATH`. Two of them give you two CLIs disagreeing about which socket to use,
and errors that change with whichever shell you opened first. This repo installs the Docker Desktop
cask.

Leaner alternative, when the Desktop VM is more than you need:

```bash
brew install colima docker docker-compose
colima start --cpu 4 --memory 8
```

## Java

Install it only when you need it: `brew install --cask corretto`. Then set `JAVA_HOME` in
`~/.zshrc.local`. That value is per-machine and does not belong in a shared dotfile.
