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

  # settings.json is MERGED, not symlinked — and this is not a style choice.
  #
  # VS Code writes to this file itself: extensions persist state into it, and
  # several of them persist secrets. On the machine this repo was distilled
  # from it held an ANTHROPIC_AUTH_TOKEN and a localhost service URL, put there
  # by an extension's settings UI, not by hand. A symlink would have committed
  # both to a public repo the next time the extension touched them.
  #
  # So: the repo's keys are authoritative for the keys the repo declares, and
  # anything else already in the file is left alone. Same rule as ~/.gitconfig.
  # python3 is guaranteed present — the Command Line Tools ship it, and
  # preflight installs those.
  if [ "$DRY_RUN" = "1" ]; then
    skip "would merge dotfiles/vscode/settings.json into $VSCODE_USER_DIR/settings.json"
  else
    # backup_copy, NOT backup: the merge below reads this same file. `backup`
    # moves it aside, so the merge would find nothing, start from an empty
    # object and write only the repo's keys — silently deleting every setting
    # VS Code had put there itself.
    backup_copy "$VSCODE_USER_DIR/settings.json"
    MACSTRAP_ROOT="$MACSTRAP_ROOT" VSCODE_USER_DIR="$VSCODE_USER_DIR" python3 - <<'PY'
import collections, json, os, re

dst = os.path.join(os.environ["VSCODE_USER_DIR"], "settings.json")
src = os.path.join(os.environ["MACSTRAP_ROOT"], "dotfiles/vscode/settings.json")


def load(path):
    """VS Code writes JSONC: line comments, block comments, trailing commas.

    The comment patterns are deliberately anchored to the start of a line.
    Stripping `//` anywhere would eat the rest of any line containing a URL —
    and this file holds URLs (an extension's endpoint, a proxy address), so an
    unanchored pattern would silently corrupt real settings rather than fail
    loudly. Comments inside a value are left alone; JSON has no way to express
    one, so they cannot occur there.
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
    # Refuse rather than guess. This script runs under `set -e`, so raising
    # would kill the whole editors step; and whatever is unparseable here is a
    # file the user edited by hand, which makes overwriting it the worst of the
    # available options. The backup_copy above is already in place.
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
