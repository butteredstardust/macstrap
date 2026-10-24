#!/usr/bin/env python3
"""Merge or check VS Code user settings against dotfiles/vscode/settings.json.

WARNING: `merge` rewrites the target file in place. Call backup_copy first.

  vscode-settings.py merge <settings.json>   repo keys win; all other keys stay
  vscode-settings.py check <settings.json>   read-only; exit 1 on drift

Target the python3 that the Command Line Tools ship (3.9). Use no newer syntax.
"""
import collections
import json
import os
import re
import sys

SRC = os.path.join(
    os.environ.get("MACSTRAP_ROOT", os.path.join(os.path.dirname(__file__), "..")),
    "dotfiles/vscode/settings.json",
)

# The repo does not declare these keys, so the merge never resets them. Each
# value here turns off a prompt that stands between a cloned repo and code
# execution. docs/07-editors.md explains why the repo leaves them on.
RISKY = {
    "security.workspace.trust.enabled": False,
    "security.promptForLocalFileProtocolHandling": False,
}


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
    with open(path) as fh:
        text = fh.read()
    text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
    text = re.sub(r"^\s*/\*.*?\*/", "", text, flags=re.M | re.S)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    if not text.strip():
        return collections.OrderedDict()
    return json.loads(text, object_pairs_hook=collections.OrderedDict)


def merge(dst):
    try:
        merged = load(dst)
    except ValueError as exc:
        # Refuse rather than guess. A non-zero exit would kill the whole
        # editors step under `set -e`. An unparseable file here is one the user
        # edited by hand, so overwriting it is the worst available option.
        print("  !! %s is not valid JSON/JSONC: %s" % (dst, exc))
        print("  !! settings left untouched. Fix the file, then re-run scripts/editors.sh")
        return 0

    added = []
    for key, value in load(SRC).items():
        if key not in merged:
            added.append(key)
        merged[key] = value

    with open(dst, "w") as fh:
        json.dump(merged, fh, indent=2)
        fh.write("\n")

    print("  ok settings.json merged (%d added, %d kept)" % (len(added), len(merged) - len(added)))
    return 0


def check(dst):
    if not os.path.exists(dst):
        print("  !! %s is missing; run scripts/editors.sh" % dst)
        return 1
    try:
        local = load(dst)
    except ValueError as exc:
        print("  !! %s is not valid JSON/JSONC: %s" % (dst, exc))
        return 1

    drift = 0
    for key, value in load(SRC).items():
        if local.get(key) != value:
            print("  !! VS Code %s differs from the repo; scripts/editors.sh resets it" % key)
            drift += 1
    for key, value in RISKY.items():
        if local.get(key) == value:
            print("  !! VS Code %s is %s; see docs/07-editors.md" % (key, json.dumps(value)))
            drift += 1

    if drift == 0:
        print("  ok VS Code settings match the repo")
    return 1 if drift else 0


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("merge", "check"):
        print("usage: vscode-settings.py merge|check <settings.json>", file=sys.stderr)
        sys.exit(2)
    sys.exit(merge(sys.argv[2]) if sys.argv[1] == "merge" else check(sys.argv[2]))
