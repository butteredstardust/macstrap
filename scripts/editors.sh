#!/usr/bin/env bash
# Editor configuration: VS Code settings + extensions, Zed settings.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Editors"

# --- VS Code --------------------------------------------------------------
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

if have code; then
  run mkdir -p "$VSCODE_USER_DIR"
  link dotfiles/vscode/settings.json "$VSCODE_USER_DIR/settings.json"

  log "Installing extensions"
  installed="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
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

# --- Zed ------------------------------------------------------------------
if [ -d "/Applications/Zed.app" ] || have zed; then
  link dotfiles/zed/settings.json "$HOME/.config/zed/settings.json"
else
  skip "Zed not installed"
fi

# --- Claude Code ----------------------------------------------------------
# Not available via Homebrew; it ships its own installer that self-updates.
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
