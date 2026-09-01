#!/usr/bin/env bash
# Static checks. Read-only — safe to run anywhere, including CI.
#
#   scripts/test.sh
#
# Exists because the expensive bugs in this repo were all things a dry-run
# could not catch: a flag that only fails when actually executed, a BSD-vs-GNU
# regex difference, a PATH that only breaks on a machine without Homebrew.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fails=0
fail() { warn "$*"; fails=$((fails + 1)); }

# --- 1. Syntax, under the OLDEST bash we must support ---------------------
# /bin/bash on macOS is 3.2. A script that only parses under Homebrew's bash 5
# breaks on exactly the fresh machine this repo exists to provision.
header "bash 3.2 syntax"
for f in "$MACSTRAP_ROOT"/bootstrap.sh "$MACSTRAP_ROOT"/scripts/*.sh; do
  if /bin/bash -n "$f" 2>/dev/null; then
    ok "$(basename "$f")"
  else
    fail "$(basename "$f") does not parse under /bin/bash"
  fi
done

# --- 2. ShellCheck --------------------------------------------------------
header "shellcheck"
if have shellcheck; then
  for f in "$MACSTRAP_ROOT"/bootstrap.sh "$MACSTRAP_ROOT"/scripts/*.sh; do
    if shellcheck -S warning -e SC1091 "$f"; then
      ok "$(basename "$f")"
    else
      fail "$(basename "$f") has shellcheck warnings"
    fi
  done
else
  skip "shellcheck not installed (brew install shellcheck)"
fi

# --- 3. GNU-only constructs -----------------------------------------------
# The tools here are BSD. `\|` alternation in BRE matches nothing rather than
# erroring, so this class of bug is silent — it has already bitten twice.
header "BSD tool compatibility"
# --exclude this file throughout: it necessarily contains the very patterns it
# searches for, and would otherwise always fail against itself.
if grep -rnE "(sed|grep)( -[a-zA-Z]+)* ['\"][^'\"]*\\\\\|" \
     "$MACSTRAP_ROOT/scripts" "$MACSTRAP_ROOT/bootstrap.sh" \
     --exclude="test.sh" 2>/dev/null; then
  fail "BRE '\\|' alternation found — BSD sed/grep silently match nothing. Use -E."
else
  ok "no BRE alternation"
fi

# -E here for the same reason this check exists at all.
if grep -rnE "date \+%N|readlink -f|sed -i '[^']" \
     "$MACSTRAP_ROOT/scripts" --exclude="test.sh" 2>/dev/null; then
  fail "GNU-only tool usage found (date %N / readlink -f / sed -i without arg)"
else
  ok "no GNU-only flags"
fi

# --- 4. Brewfile hygiene --------------------------------------------------
header "Brewfiles"
for bundle in Brewfile Brewfile.apps Brewfile.optional; do
  f="$MACSTRAP_ROOT/$bundle"
  [ -f "$f" ] || continue
  # A flag that does not exist only fails at execution time, never in a dry run.
  if grep -q -- '--no-lock' "$f"; then
    fail "$bundle references --no-lock, which brew bundle rejects"
  fi
  ok "$bundle present"
done

if grep -rn -- '--no-lock' "$MACSTRAP_ROOT/scripts" --exclude="test.sh" >/dev/null 2>&1; then
  fail "scripts still pass --no-lock to brew bundle (invalid option, exits 1)"
else
  ok "no --no-lock in scripts"
fi

# Duplicate declarations across bundles: installing the same thing twice from
# two files is the exact drift this repo exists to prevent.
dupes="$(cat "$MACSTRAP_ROOT"/Brewfile* 2>/dev/null \
  | sed -nE 's/^[[:space:]]*(brew|cask) "([^"]*)".*/\2/p' \
  | sed 's#.*/##' | sort | uniq -d)"
if [ -n "$dupes" ]; then
  fail "declared in more than one Brewfile: $(echo "$dupes" | tr '\n' ' ')"
else
  ok "no duplicate declarations"
fi

# --- 5. Secret / identity scan --------------------------------------------
header "privacy"
# Anything matching here would identify the author once the repo is public.
if grep -rniE '(api[_-]?key|auth[_-]?token|secret[_-]?key|password)[[:space:]]*=[[:space:]]*["'\''][^"'\'']+' \
     "$MACSTRAP_ROOT" --exclude-dir=.git --exclude="test.sh" >/dev/null 2>&1; then
  fail "possible hardcoded credential"
else
  ok "no hardcoded credentials"
fi

# A literal home path leaks the account name. $HOME is the portable form, and
# a hardcoded one would also simply be wrong on anyone else's machine.
if grep -rn '/Users/[a-z]' "$MACSTRAP_ROOT" \
     --exclude-dir=.git --exclude="test.sh" >/dev/null 2>&1; then
  fail "hardcoded /Users/<name> path found — use \$HOME"
  grep -rn '/Users/[a-z]' "$MACSTRAP_ROOT" --exclude-dir=.git --exclude="test.sh" | head -5
else
  ok "no hardcoded home paths"
fi

# --- 6. Docs referential integrity ----------------------------------------
header "docs"
missing=0
for doc in $(grep -ohE 'docs/[0-9]{2}-[a-z-]+\.md' "$MACSTRAP_ROOT"/README.md \
             "$MACSTRAP_ROOT"/docs/*.md "$MACSTRAP_ROOT"/scripts/*.sh 2>/dev/null | sort -u); do
  [ -f "$MACSTRAP_ROOT/$doc" ] || { fail "referenced but missing: $doc"; missing=1; }
done
[ "$missing" = "0" ] && ok "all doc cross-references resolve"

printf '\n'
if [ "$fails" -eq 0 ]; then
  ok "all static checks passed"
else
  die "$fails check(s) failed"
fi
