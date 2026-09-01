# 05 — Language toolchains

Principle: **the machine gets a manager, the project gets a version.** Anything installed globally
is something you invoke outside a project directory. Everything else is pinned in the repo.

| Language | Manager | Project pin |
|---|---|---|
| Rust | `rustup` | `rust-toolchain.toml` |
| Node | Homebrew `node` + `corepack` | `.nvmrc`, `packageManager` in `package.json` |
| Python | `uv` | `pyproject.toml` + `uv.lock` |

## Rust

The Homebrew formula is `rustup`, **not** `rust`. The `rust` formula pins one compiler version with
no way to add targets or switch channels.

```bash
brew install rustup
rustup default stable
rustup component add rust-analyzer clippy rustfmt
```

**Two gotchas, and each one alone leaves you with a broken Rust:**

1. **The formula is keg-only.** It conflicts with the `rust` formula, so Homebrew never symlinks it
   into `bin/`. After a successful install, `rustup` and `cargo` are still `command not found`. The
   binaries are at `$(brew --prefix)/opt/rustup/bin`, which `.zshrc` adds to `PATH`:

   ```zsh
   path_prepend /opt/homebrew/opt/rustup/bin
   ```

   Hardcoded rather than calling `brew --prefix rustup`, which would add ~100ms to every shell start.

2. **It installs the manager, not a toolchain.** Once found, every `cargo` invocation fails with
   `no default toolchain configured` until you run `rustup default stable`.

`scripts/languages.sh` handles both, and warns explicitly if `rustup` is missing from `PATH` rather
than silently skipping the step.

`~/.cargo/env` is sourced from `.zshenv`, not `.zshrc`, so editors and build scripts that never see
`.zshrc` still find `cargo`.

```bash
rustup update
rustup target add aarch64-apple-darwin x86_64-apple-darwin   # universal binaries
cargo clippy -- -D warnings
```

## Node

```bash
brew install node pnpm
```

**Corepack is no longer bundled.** It is what honours the `packageManager` field in `package.json`,
but Node unbundled it in v25 and Homebrew ships v26 — so `corepack enable` now fails with
`command not found`, and per-project package-manager pinning is silently not enforced. If you rely
on that pin:

```bash
npm install -g corepack && corepack enable
```

`scripts/languages.sh` reports which of the two states you are in rather than assuming.

| Manager | Use |
|---|---|
| `pnpm` | default — content-addressed store, strict by default, fast |
| `bun` | runtime + test runner + bundler; also a fast installer |
| `npm` | when a project ships an `npm`-shaped lockfile |
| `nvm` | only when a project pins an old Node. It costs ~200ms of shell startup, so it is in `Brewfile.optional` |

**Do not install project dependencies globally.** A global `typescript` that is a major version
ahead of the project's will be picked up by editor tooling and produce errors that do not reproduce
in CI.

## Python

`uv` replaces `pyenv` + `pipx` + `virtualenv` + `pip-tools`. One tool, written in Rust, fast enough
that nothing else earns its place.

```bash
uv python install 3.13      # manage interpreters
uv init && uv add requests  # project + deps, writes uv.lock
uv run script.py            # runs in the project env, no activation
uv tool install ruff        # global CLI in its own isolated venv
```

### Migrating off pipx and conda

If you already have them, `uv` takes over both without ceremony:

```bash
pipx list --short                       # what you would lose
uv tool install --force <each-one>      # --force: pipx's shims are still in ~/.local/bin
brew uninstall pipx                     # only after verifying each tool still runs
```

`--force` is not optional. Both write executables to `~/.local/bin`, so `uv tool install` stops with
`Executables already exist` until pipx's shims are overwritten. Verify with `<tool> --version`
*before* uninstalling pipx, not after — the shims and the real installs live in the same directory.

For conda: check `conda env list` first. If `base` is the only environment, nothing is using it and
the cask can go. Removing it also lets you delete the `conda init` block from `.zshrc`, which is
worth roughly 150ms on every shell you open. Note that `brew uninstall --cask miniforge` shells out
to `sudo`, so it needs a real terminal.

**Never `pip install` into the system Python.** macOS ships `/usr/bin/python3` for its own use;
writing to it breaks OS tooling and is wiped by system updates. Recent versions refuse with
`externally-managed-environment`, which is the OS protecting you.

Globally installed via `uv tool`:

| Tool | Role |
|---|---|
| `ruff` | linter + formatter; replaces flake8, isort, black |
| `pyright` | type checker; same engine as VS Code's Pylance |

## Containers

Docker Desktop is installed as a cask. **Install exactly one Docker.** The `docker` formula and the
`docker` / `docker-desktop` casks all place a `docker` binary on `PATH`; with more than one you get
two CLIs disagreeing about which socket to use, and errors that change depending on which shell you
opened first.

Leaner alternative, if the Desktop VM is more than you need:

```bash
brew install colima docker docker-compose
colima start --cpu 4 --memory 8
```

## Java

Only if you need it. `brew install --cask corretto`, then set `JAVA_HOME` in `~/.zshrc.local` —
it is per-machine and does not belong in a shared dotfile.
