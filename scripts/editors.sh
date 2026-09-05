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
    MACSTRAP_ROOT="$MACSTRAP_ROOT" VSCODE_USER_DIR="$VSCODE_USER_DIR" python3 - <<'PY'
import collections, json, os, re

dst = os.path.join(os.environ["VSCODE_USER_DIR"], "settings.json")
src = os.path.join(os.environ["MACSTRAP_ROOT"], "dotfiles/vscode/settings.json")


def load(path):
    """Parse the JSONC that VS Code writes: line and block comments, trailing commas.

    Keep both comment patterns anchored to the start of a line. Stripping `//`
    anywhere would eat the rest of any line holding a URL, and this file holds
    URLs such as an extension endpoint or a proxy address. An unanchored pattern
    would corrupt real settings instead of failing loudly. Comments inside a
    value stay untouched, and JSON cannot express one anyway.
    """
    if not os.path.exists(path):
        return collections.OrderedDict()
    text = open(path).read()
    text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
    text = re.sub(r"^\s*/\*.*?\*/", "", text, flags=re.M | re.S)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    if not text.strip():
        return collections.OrderedDict()
    return json.loads(text, object_pairs_hook=collections.OrderedDict)


try:
    merged = load(dst)
except ValueError as exc:
    # Refuse rather than guess. Raising would kill the whole editors step under
    # `set -e`. An unparseable file here is one the user edited by hand, so
    # overwriting it is the worst available option. The backup_copy above is
    # already in place.
    print("  !! %s is not valid JSON/JSONC: %s" % (dst, exc))
    print("  !! settings left untouched. Fix the file, then re-run scripts/editors.sh")
    raise SystemExit(0)

added = []
for key, value in load(src).items():
    if key not in merged:
        added.append(key)
    merged[key] = value

with open(dst, "w") as fh:
    json.dump(merged, fh, indent=2)
    fh.write("\n")

print("  ok settings.json merged (%d added, %d kept)" % (len(added), len(merged) - len(added)))
PY
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
