#!/usr/bin/env bash
# Language toolchains and the few globally-installed dev tools worth having.
#
# Deliberately short. Per-project versions belong to the project (.nvmrc,
# rust-toolchain.toml, uv's pyproject) — a machine-wide install is only for
# tools you invoke *outside* a project.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Language toolchains"

activate_homebrew || warn "Homebrew not found; only tools already on PATH will be configured"

# --- Rust -----------------------------------------------------------------
# Two separate traps here, and hitting either leaves you with a broken Rust:
#
#   1. The formula is KEG-ONLY (it conflicts with the `rust` formula), so
#      Homebrew never symlinks it into bin/. `rustup` and `cargo` are simply
#      absent from PATH until $(brew --prefix rustup)/bin is added.
#      activate_homebrew does that for this run; .zshrc does it permanently.
#   2. Even once found, the formula installs the MANAGER only — no toolchain.
#      Every cargo invocation then fails with "no default toolchain configured".
if have rustup; then
  if rustup show active-toolchain >/dev/null 2>&1; then
    ok "rust: $(rustc --version 2>/dev/null || echo 'toolchain installed')"
  else
    log "Installing the stable Rust toolchain"
    run rustup default stable
    run rustup component add rust-analyzer clippy rustfmt
  fi
else
  warn "rustup not on PATH — it is keg-only; expected at $(brew_prefix_expected)/opt/rustup/bin"
fi

# --- Node -----------------------------------------------------------------
if have node; then
  ok "node $(node --version), pnpm $(pnpm --version 2>/dev/null || echo 'missing')"

  # Corepack is what honours package.json's "packageManager" field, pinning the
  # package manager per project. Node stopped bundling it in v25, and Homebrew
  # now ships v26 — so on a current machine it is simply absent and the pin is
  # silently not enforced. Install it explicitly if you want that guarantee.
  if have corepack; then
    run corepack enable
    ok "corepack enabled — \"packageManager\" pins are honoured"
  else
    skip "corepack absent (unbundled from Node 25+); \"packageManager\" pins are NOT enforced"
    skip "  to enable: npm install -g corepack && corepack enable"
  fi
else
  skip "node not installed"
fi

have bun && ok "bun $(bun --version)"

# --- Python ---------------------------------------------------------------
# uv replaces pyenv + pipx + virtualenv + pip-tools. It manages interpreters
# (`uv python install`), project envs (`uv sync`) and global CLI tools
# (`uv tool install`), and is fast enough that nothing else is worth the
# maintenance.
if have uv; then
  ok "uv $(uv --version | awk '{print $2}')"
  log "Installing global Python CLI tools"
  # Each lands in its own isolated venv, exposed on ~/.local/bin.
  for tool in ruff pyright; do
    if uv tool list 2>/dev/null | grep -q "^$tool "; then
      skip "uv tool: $tool"
    else
      run uv tool install "$tool"
    fi
  done
else
  skip "uv not installed"
fi

# --- Language servers -----------------------------------------------------
# Only needed by editors that do not bundle their own (Zed, Neovim). VS Code's
# extensions ship theirs, so this is optional.
if [ "${WITH_LSP:-0}" = "1" ] && have npm; then
  log "Installing Node-based language servers globally"
  run npm install -g typescript typescript-language-server vscode-langservers-extracted
else
  skip "language servers (set WITH_LSP=1 to install)"
fi

ok "Toolchains complete"
