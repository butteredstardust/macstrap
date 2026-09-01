#!/usr/bin/env bash
# Install the Brewfiles.
#
#   scripts/packages.sh                 core + apps
#   WITH_OPTIONAL=1 scripts/packages.sh core + apps + optional
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Packages"

activate_homebrew || die "Homebrew not found — run scripts/homebrew.sh first"

bundles="Brewfile Brewfile.apps"
[ "${WITH_OPTIONAL:-0}" = "1" ] && bundles="$bundles Brewfile.optional"

for bundle in $bundles; do
  file="$MACSTRAP_ROOT/$bundle"
  [ -f "$file" ] || { warn "no such bundle: $bundle"; continue; }

  log "brew bundle --file=$bundle"
  # --no-upgrade: leave already-installed formulae at their current version.
  # Upgrading is topgrade's job, not provisioning's.
  #
  # There is deliberately no --no-lock here: `brew bundle` has no lockfile
  # concept and rejects the flag outright with `Error: invalid option`.
  #
  # Brewfile.optional is allowed to fail without killing the run. It contains
  # the `mas` entries, and a single App Store problem — signed out, wrong
  # region, an app never associated with the Apple ID — makes brew bundle exit
  # non-zero. That must not stop dotfiles, languages and editors from being
  # set up, which all run after this step.
  if [ "$bundle" = "Brewfile.optional" ]; then
    run brew bundle install --file="$file" --no-upgrade || {
      warn "optional bundle had failures (App Store entries are the usual cause)"
      warn "core provisioning continues; re-run with: brew bundle install --file=$bundle"
    }
  else
    run brew bundle install --file="$file" --no-upgrade
  fi
done

# Casks that install a font need the font cache refreshed before apps see it;
# macOS does this on its own, but not always before the next launch.
if [ "$DRY_RUN" != "1" ]; then
  for _font_cask in "$(brew --prefix)"/Caskroom/font-*; do
    [ -e "$_font_cask" ] || break     # unmatched glob stays literal in bash
    ok "fonts installed — restart running terminals to pick them up"
    break
  done
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
  # Only concatenate bundles that exist. Brewfile.optional is documented as
  # "delete freely", and under `set -o pipefail` a missing file would abort the
  # whole step rather than degrade.
  existing=""
  for b in Brewfile Brewfile.apps Brewfile.optional; do
    [ -f "$MACSTRAP_ROOT/$b" ] && existing="$existing $MACSTRAP_ROOT/$b"
  done

  # shellcheck disable=SC2086  # word splitting is the point here
  cat $existing \
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
