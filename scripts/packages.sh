#!/usr/bin/env bash
# Install the Brewfiles.
#
#   scripts/packages.sh                 core + apps
#   WITH_OPTIONAL=1 scripts/packages.sh core + apps + optional
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Packages"

have brew || die "Homebrew not on PATH — run scripts/homebrew.sh first"

bundles="Brewfile Brewfile.apps"
[ "${WITH_OPTIONAL:-0}" = "1" ] && bundles="$bundles Brewfile.optional"

for bundle in $bundles; do
  file="$MACSTRAP_ROOT/$bundle"
  [ -f "$file" ] || { warn "no such bundle: $bundle"; continue; }

  log "brew bundle --file=$bundle"
  # --no-lock: a Brewfile.lock.json pins resolved versions, which is useful for
  # a team but just churn for a personal machine that always wants latest.
  # --no-upgrade: leave already-installed formulae at their current version;
  # upgrading is topgrade's job, not provisioning's.
  run brew bundle install --file="$file" --no-lock --no-upgrade
done

# Casks that install a font need the font cache refreshed before apps see it;
# macOS does this on its own, but not always before the next launch.
if [ "$DRY_RUN" != "1" ] && ls "$(brew --prefix)/Caskroom" 2>/dev/null | grep -q '^font-'; then
  ok "fonts installed — restart running terminals to pick them up"
fi

# --- Drift report ---------------------------------------------------------
# Anything installed by hand and never written down is the cruft this repo
# exists to prevent. Report it rather than removing it: deleting packages
# without being asked is not a provisioning script's call.
if [ "$DRY_RUN" != "1" ]; then
  log "Checking for packages installed outside the Brewfiles"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # -E (ERE): BSD sed's basic regex has no `\|` alternation, so a BRE version of
  # this silently matches nothing and reports every package as undeclared.
  # Trailing `s#.*/##` strips the tap prefix from e.g. oven-sh/bun/bun.
  cat "$MACSTRAP_ROOT"/Brewfile "$MACSTRAP_ROOT"/Brewfile.apps \
      "$MACSTRAP_ROOT"/Brewfile.optional 2>/dev/null \
    | sed -nE 's/^[[:space:]]*(brew|cask) "([^"]*)".*/\2/p' \
    | sed 's#.*/##' | sort -u > "$tmp/declared"

  { brew leaves; brew list --cask; } 2>/dev/null | sort -u > "$tmp/installed"

  if extra="$(comm -13 "$tmp/declared" "$tmp/installed")" && [ -n "$extra" ]; then
    warn "installed but not in any Brewfile:"
    printf '       %s\n' $extra
    warn "either add them to a Brewfile or 'brew uninstall' them"
  else
    ok "no undeclared packages"
  fi
fi

ok "Packages complete"
