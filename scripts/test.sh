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
# In a repository, scan exactly what could be published: tracked files plus
# untracked, non-ignored files. Local logs, caches and Brewfile.local are
# intentionally outside that boundary. Fall back to the old recursive scan
# when git is unavailable or this copy is not a worktree.
privacy_files="$TMPDIR_TEST/privacy-files"
privacy_uses_git=0
if have git && git -C "$MACSTRAP_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$MACSTRAP_ROOT" ls-files --cached --others --exclude-standard > "$privacy_files"
  privacy_uses_git=1
fi

privacy_match() {
  local pattern="$1" rel
  if [ "$privacy_uses_git" = "1" ]; then
    while IFS= read -r rel; do
      [ "$rel" = "scripts/test.sh" ] && continue
      [ -f "$MACSTRAP_ROOT/$rel" ] || continue
      grep -niE "$pattern" "$MACSTRAP_ROOT/$rel" >/dev/null 2>&1 && return 0
    done < "$privacy_files"
    return 1
  fi
  grep -rniE "$pattern" "$MACSTRAP_ROOT" \
    --exclude-dir=.git --exclude="test.sh" >/dev/null 2>&1
}

# Anything matching here would identify the author once the repo is public.
if privacy_match '(api[_-]?key|auth[_-]?token|secret[_-]?key|password)[[:space:]]*=[[:space:]]*["'\''][^"'\'']+'; then
  fail "possible hardcoded credential"
else
  ok "no hardcoded credentials"
fi

# A literal home path leaks the account name. $HOME is the portable form, and
# a hardcoded one would also simply be wrong on anyone else's machine.
if privacy_match '/Users/[a-z]'; then
  fail "hardcoded /Users/<name> path found — use \$HOME"
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
  actions_seen=0
  for action in \
    "would run: rustup default stable" \
    "would run: uv tool install ruff" \
    "would merge dotfiles/vscode/settings.json" \
    "would run: code --install-extension"
  do
    grep -Fq "$action" "$TMPDIR_TEST/fresh.log" && actions_seen=$((actions_seen + 1))
  done
  if [ "$actions_seen" -eq 4 ]; then
    ok "dry run previews real language and editor actions with no Homebrew present"
  else
    fail "dry run exited 0 but only previewed $actions_seen/4 required actions"
  fi
else
  fail "dry run fails on a machine without Homebrew (exit $?)"
  tail -5 "$TMPDIR_TEST/fresh.log" | sed 's/^/       /'
fi

# --- 7. PATH activation regressions ---------------------------------------
header "Homebrew PATH activation"

# editors.sh must activate Homebrew itself: bootstrap runs every step in a
# separate child, so the PATH changed by homebrew.sh cannot reach this script.
#
# Assert the CALL, via a stub that records being invoked — not the output. The
# obvious version of this test asserts that the settings merge and an extension
# install were previewed, and it passes whether or not editors.sh activates
# anything: `have code || [ "$DRY_RUN" = "1" ]` previews them regardless. That
# version was written, passed, and still passed with the activate_homebrew line
# commented out. A test that cannot fail is worse than no test, because it is
# also a claim.
marker="$TMPDIR_TEST/activate-called"
if env -u BASH_ENV PATH="/usr/bin:/bin:/usr/sbin:/sbin" DRY_RUN=1 \
     MACSTRAP_TEST_MARKER="$marker" \
     bash -c '. "$1/scripts/lib.sh"
              activate_homebrew() { : > "$MACSTRAP_TEST_MARKER"; }
              . "$1/scripts/editors.sh"' \
     _ "$MACSTRAP_ROOT" > "$TMPDIR_TEST/editors.log" 2>&1 \
   && [ -f "$marker" ]; then
  ok "editors.sh calls activate_homebrew before looking for code"
else
  fail "editors.sh never called activate_homebrew — 'code' is invisible on a fresh Mac"
fi

# Seeing brew already must not short-circuit the keg-only rustup PATH entry.
brew_bin="$TMPDIR_TEST/brew-bin"
brew_prefix_test="$TMPDIR_TEST/brew-prefix"
mkdir -p "$brew_bin" "$brew_prefix_test/opt/rustup/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$MACSTRAP_TEST_BREW_PREFIX"\n' > "$brew_bin/brew"
printf '#!/bin/sh\nexit 0\n' > "$brew_prefix_test/opt/rustup/bin/cargo"
chmod +x "$brew_bin/brew" "$brew_prefix_test/opt/rustup/bin/cargo"
if env -u BASH_ENV PATH="$brew_bin:/usr/bin:/bin" \
     MACSTRAP_TEST_BREW_PREFIX="$brew_prefix_test" \
     bash -c '. "$1/scripts/lib.sh"; activate_homebrew; command -v cargo' _ "$MACSTRAP_ROOT" \
     > "$TMPDIR_TEST/cargo-path" 2>/dev/null \
   && grep -Fq "$brew_prefix_test/opt/rustup/bin/cargo" "$TMPDIR_TEST/cargo-path"; then
  ok "activate_homebrew adds keg-only rustup even when brew is already visible"
else
  fail "activate_homebrew skipped the keg-only rustup PATH"
fi

# --- 8. Docs referential integrity ----------------------------------------
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
