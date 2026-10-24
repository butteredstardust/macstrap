#!/usr/bin/env bash
# Editor configuration: VS Code settings + extensions, and the Claude Code CLI.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Editors"

activate_homebrew || warn "Homebrew not found; only editors already on PATH will be configured"

# --- VS Code --------------------------------------------------------------
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

if have code || [ "$DRY_RUN" = "1" ]; then
  run mkdir -p "$VSCODE_USER_DIR"

  # MERGE settings.json, never symlink it.
  #
  # VS Code writes to this file itself. Extensions persist state into it, and
  # several persist secrets — auth tokens and localhost service URLs land here,
  # written by an extension's settings UI rather than by hand. A symlink would
  # publish them to this public repo the next time an extension saved.
  #
  # So the repo's keys win for the keys the repo declares, and everything else
  # in the file stays untouched. Same rule as ~/.gitconfig.
  #
  # python3 is always present: the Command Line Tools ship it, and preflight
  # installs those.
  if [ "$DRY_RUN" = "1" ]; then
    skip "would merge dotfiles/vscode/settings.json into $VSCODE_USER_DIR/settings.json"
  else
    # Use backup_copy, NOT backup. The merge below reads this same file.
    # `backup` moves it aside, so the merge would find nothing, start from an
    # empty object, and write only the repo's keys. That would remove every
    # setting VS Code put there itself.
    backup_copy "$VSCODE_USER_DIR/settings.json"
    python3 "$MACSTRAP_ROOT/scripts/vscode-settings.py" merge "$VSCODE_USER_DIR/settings.json"
  fi

  log "Installing extensions"
  if [ "$DRY_RUN" = "1" ]; then
    installed=""
  else
    installed="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  fi
  while IFS= read -r ext; do
    # Strip comments and blank lines.
    ext="${ext%%#*}"
    ext="$(echo "$ext" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
    [ -z "$ext" ] && continue

    if echo "$installed" | grep -qx "$ext"; then
      skip "$ext"
    else
      run code --install-extension "$ext" --force
    fi
  done < "$MACSTRAP_ROOT/dotfiles/vscode/extensions.txt"
else
  warn "the 'code' command is not on PATH"
  warn "open VS Code and run: Shell Command: Install 'code' command in PATH"
fi

# --- Claude Code ----------------------------------------------------------
# Homebrew does not carry it. It ships its own self-updating installer.
if have claude; then
  ok "claude $(claude --version 2>/dev/null | head -1)"
elif confirm "Install Claude Code CLI?"; then
  if [ "$DRY_RUN" = "1" ]; then
    skip "would install Claude Code"
  else
    curl -fsSL https://claude.ai/install.sh | bash
  fi
else
  skip "Claude Code"
fi

ok "Editors complete"
