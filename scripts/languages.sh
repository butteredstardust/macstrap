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
#      Homebrew does not symlink its binaries into bin/ — except `rustup`
#      itself, which its post-install step does link. That asymmetry is the
#      confusing part: `rustup` answers fine while `cargo` is not found at all,
#      which reads as a broken toolchain rather than a missing PATH entry.
#      Both live in $(brew --prefix rustup)/bin. activate_homebrew adds it for
#      this run; .zshenv does it permanently (.zshenv, not .zshrc — a build
#      script running `zsh -c cargo build` never reads the latter).
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
elif [ "$DRY_RUN" = "1" ]; then
  log "Installing the stable Rust toolchain"
  run rustup default stable
  run rustup component add rust-analyzer clippy rustfmt
else
  warn "rustup not on PATH — it is keg-only; expected at $(brew_prefix_expected)/opt/rustup/bin"
fi

# --- Node -----------------------------------------------------------------
# pnpm comes from Homebrew and nothing else installs it. Corepack would be the
# alternative owner, but it cannot honour a `packageManager` field pinned to
# bun, and installing both leaves two owners of the same two binaries. The one
# thing worth actively warning about is `npm install -g pnpm`: npm's global bin
# overwrites Homebrew's symlinks and removes them on uninstall, which presents
# as `pnpm: command not found` while `brew list` still shows it installed.
if have node || [ "$DRY_RUN" = "1" ]; then
  if have pnpm; then
    ok "node $(node --version), pnpm $(pnpm --version)"
    case "$(command -v pnpm)" in
      "$(brew_prefix_expected)"/*) ;;
      *) warn "pnpm resolves to $(command -v pnpm), not Homebrew — an npm -g install shadows the formula" ;;
    esac
  elif [ "$DRY_RUN" = "1" ]; then
    skip "would use the Homebrew pnpm formula (not corepack; see docs/05-languages.md)"
  else
    warn "pnpm missing — run scripts/packages.sh; do not install it with npm -g"
  fi

  if have corepack; then
    warn "corepack is installed as well as pnpm — both own pnpm/pnpx; keep one (docs/05)"
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
if have uv || [ "$DRY_RUN" = "1" ]; then
  if have uv; then
    ok "uv $(uv --version | awk '{print $2}')"
  else
    skip "would configure uv after Homebrew installs it"
  fi
  log "Installing global Python CLI tools"
  # Each lands in its own isolated venv, exposed on ~/.local/bin.
  for tool in ruff pyright; do
    if have uv && uv tool list 2>/dev/null | grep -q "^$tool "; then
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
