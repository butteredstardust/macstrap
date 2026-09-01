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

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
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

# --- 6. Fresh-machine dry run ---------------------------------------------
# The one behavioural test here, and it earns its runtime: every serious bug
# this repo has had was invisible on a provisioned machine and only appeared
# where nothing was installed yet. Static checks cannot catch those.
#
# Simulate it by copying the repo and stubbing brew_prefix() to fail, which is
# what a Mac with no Homebrew looks like to these scripts. Then assert that
# --dry-run previews ALL of it. It used to die at the packages step, so
# `./bootstrap.sh --dry-run` — the first command the README suggests — showed a
# new user two steps out of six and exited 1.
#
# Nothing is installed or modified: DRY_RUN=1 routes every action through
# `run`, which prints.
header "fresh-machine dry run"
fresh="$TMPDIR_TEST/fresh"
cp -R "$MACSTRAP_ROOT" "$fresh" 2>/dev/null
rm -rf "$fresh/.git"

# Insert the stub as the first line of the function body.
awk '/^brew_prefix\(\) \{$/ { print; print "  return 1  # test stub: no Homebrew"; next } { print }' \
  "$fresh/scripts/lib.sh" > "$fresh/scripts/lib.sh.tmp" && mv "$fresh/scripts/lib.sh.tmp" "$fresh/scripts/lib.sh"

# `env -u BASH_ENV` matters: if BASH_ENV points at a profile that appends
# Homebrew to PATH, `have brew` succeeds and the whole simulation is void —
# the run passes while testing nothing.
if env -u BASH_ENV PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
     "$fresh/bootstrap.sh" --dry-run --with-optional > "$TMPDIR_TEST/fresh.log" 2>&1; then
  steps_seen=0
  for step in Preflight Homebrew Packages Dotfiles "Language toolchains" Editors; do
    grep -qx "$step" "$TMPDIR_TEST/fresh.log" && steps_seen=$((steps_seen + 1))
  done
  if [ "$steps_seen" -eq 6 ]; then
    ok "dry run previews all 6 steps with no Homebrew present"
  else
    fail "dry run exited 0 but only previewed $steps_seen/6 steps"
  fi
else
  fail "dry run fails on a machine without Homebrew (exit $?)"
  tail -5 "$TMPDIR_TEST/fresh.log" | sed 's/^/       /'
fi

# --- 7. Docs referential integrity ----------------------------------------
header "docs"
missing=0
# Fed by a pipeline rather than `for doc in $(...)`: a path is one line, not one
# word, and word splitting would break the first filename containing a space.
grep -ohE 'docs/[0-9]{2}-[a-z-]+\.md' "$MACSTRAP_ROOT"/README.md \
     "$MACSTRAP_ROOT"/docs/*.md "$MACSTRAP_ROOT"/scripts/*.sh 2>/dev/null \
  | sort -u > "$TMPDIR_TEST/refs"
while IFS= read -r doc; do
  [ -f "$MACSTRAP_ROOT/$doc" ] || { fail "referenced but missing: $doc"; missing=1; }
done < "$TMPDIR_TEST/refs"
[ "$missing" = "0" ] && ok "all doc cross-references resolve"

printf '\n'
if [ "$fails" -eq 0 ]; then
  ok "all static checks passed"
else
  die "$fails check(s) failed"
fi
