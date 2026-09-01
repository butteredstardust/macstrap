#!/usr/bin/env bash
# Language toolchains and the few globally-installed dev tools worth having.
#
# Deliberately short. Per-project versions belong to the project (.nvmrc,
# rust-toolchain.toml, uv's pyproject) — a machine-wide install is only for
# tools you invoke *outside* a project.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Language toolchains"

# --- Rust -----------------------------------------------------------------
# The `rustup` formula installs the manager only; it does not install a
# toolchain until you ask. Skipping this step leaves `cargo` on PATH but every
# invocation failing with "no default toolchain".
if have rustup; then
  if rustup show active-toolchain >/dev/null 2>&1; then
    ok "rust: $(rustc --version 2>/dev/null || echo 'toolchain installed')"
  else
    log "Installing the stable Rust toolchain"
    run rustup default stable
    run rustup component add rust-analyzer clippy rustfmt
  fi
else
  skip "rustup not installed (it is in the core Brewfile)"
fi

# --- Node -----------------------------------------------------------------
if have node; then
  ok "node $(node --version), pnpm $(pnpm --version 2>/dev/null || echo 'missing')"
  # corepack pins the package manager per project via package.json's
  # "packageManager" field, which beats hoping everyone has the same pnpm.
  have corepack && run corepack enable || true
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
