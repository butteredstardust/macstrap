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

# Brewfile.local is yours: gitignored, never published. It is for packages that
# are real dependencies of how *you* work but have no business in a public repo
# — a personal CLI, an employer's internal tool, a tap you are not going to
# explain. Without it the only way to silence the drift report below is to
# publish the package name, which is the wrong trade.
[ -f "$MACSTRAP_ROOT/Brewfile.local" ] && bundles="$bundles Brewfile.local"

# --- Tap trust ------------------------------------------------------------
# Homebrew refuses to load formulae from a third-party tap until you trust it:
#   Error: Refusing to load formula oven-sh/bun/bun from untrusted tap
# `brew bundle` inherits that refusal, so on a fresh machine every tapped
# package here fails and the step exits non-zero. There is no Brewfile syntax
# for this — it is deliberately a separate, explicit act, because trusting a tap
# means agreeing to run its maintainers' Ruby on your machine.
#
# Which is why this asks rather than doing it silently. Answering no is a valid
# choice; the tapped packages just will not install.
# `brew trust` has no subcommand to query what is already trusted, so read its
# state file. Location per `brew trust --help`: $XDG_CONFIG_HOME/homebrew if
# that variable is set, ~/.homebrew otherwise.
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  trust_file="$XDG_CONFIG_HOME/homebrew/trust.json"
else
  trust_file="$HOME/.homebrew/trust.json"
fi

taps="$(sed -nE 's/^[[:space:]]*tap "([^"]*)".*/\1/p' "$MACSTRAP_ROOT"/Brewfile* 2>/dev/null | sort -u)"
for tap in $taps; do
  # No closing quote in the pattern on purpose. A tap can be trusted wholesale
  # ("oven-sh/bun") or one formula at a time ("minio/stable/mc"), which is what
  # `brew trust` itself recommends. Matching only the exact tap string would
  # nag about a tap whose every package you have already trusted individually.
  if [ -f "$trust_file" ] && grep -q "\"$tap" "$trust_file"; then
    skip "tap $tap already trusted"
  elif confirm "trust tap $tap? (its formulae run as code on this machine)"; then
    run brew trust --tap "$tap"
  else
    warn "$tap left untrusted — its packages will fail to install"
  fi
done

bundle_failures=0
core_bundle_failed=0
for bundle in $bundles; do
  file="$MACSTRAP_ROOT/$bundle"
  if [ ! -f "$file" ]; then
    warn "no such bundle: $bundle"
    bundle_failures=$((bundle_failures + 1))
    if [ "$bundle" = "Brewfile" ]; then
      core_bundle_failed=1
    fi
    continue
  fi

  log "brew bundle --file=$bundle"
  # --no-upgrade: leave already-installed formulae at their current version.
  # Upgrading is topgrade's job, not provisioning's.
  #
  # There is deliberately no --no-lock here: `brew bundle` has no lockfile
  # concept and rejects the flag outright with `Error: invalid option`.
  #
  # No bundle is allowed to abort the run, and the reasons differ per file.
  #
  # Brewfile.optional holds the `mas` entries, and a single App Store problem —
  # signed out, wrong region, an app never associated with the Apple ID — makes
  # brew bundle exit non-zero.
  #
  # Brewfile.apps holds casks that ship a .pkg and shell out to `sudo` (Tailscale
  # is one). Those cannot install unattended: `sudo` needs a terminal, so under
  # `--yes`, over ssh, or from CI they fail no matter what is on the Brewfile
  # line. They also cannot be adopted with `--adopt` if the app is already
  # installed from the vendor's own download.
  #
  # Aborting on any of these used to skip the drift report at the bottom, which
  # is the one part of this step that tells you what is actually on the machine.
  # Losing the diagnostic because one GUI app wanted a password is backwards.
  if ! run brew bundle install --file="$file" --no-upgrade; then
    bundle_failures=$((bundle_failures + 1))
    if [ "$bundle" = "Brewfile" ]; then
      core_bundle_failed=1
    fi
    warn "$bundle: some entries failed to install"
    case "$bundle" in
      Brewfile.optional) warn "  App Store entries are the usual cause; check 'mas account'" ;;
      Brewfile.apps)     warn "  a cask needing sudo cannot install unattended; re-run in a terminal" ;;
    esac
    warn "  retry just this file with: brew bundle install --file=$bundle"
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
  for b in Brewfile Brewfile.apps Brewfile.optional Brewfile.local; do
    [ -f "$MACSTRAP_ROOT/$b" ] && existing="$existing $MACSTRAP_ROOT/$b"
  done

  # shellcheck disable=SC2086  # word splitting is the point here
  cat $existing \
    | sed -nE 's/^[[:space:]]*(brew|cask) "([^"]*)".*/\2/p' \
    | sed 's#.*/##' | sort -u > "$tmp/declared"

  # The same `s#.*/##` as above, and for the same reason: `brew leaves` prints
  # tapped formulae fully qualified (oven-sh/bun/bun) while the Brewfile side is
  # already stripped to the bare name. Without this, every tapped package is
  # reported as undeclared. It stayed hidden until the taps were trusted —
  # Homebrew omits untrusted taps from `brew leaves` entirely, so the drift
  # report was quietly under-counting rather than over-counting.
  # Casks get renamed, and Homebrew keeps the old token working forever by
  # leaving a symlink in the Caskroom. `brew list --cask` then prints BOTH names
  # — `docker` and `docker-desktop` are one 2.3GB install, not two — and the
  # old token can never be declared, because `brew install docker` just resolves
  # to the new one. Reading the Caskroom and keeping only real directories
  # gives the canonical name exactly once.
  cask_root="$(brew --prefix)/Caskroom"
  installed_casks=""
  if [ -d "$cask_root" ]; then
    for c in "$cask_root"/*; do
      [ -d "$c" ] && [ ! -L "$c" ] && installed_casks="$installed_casks
${c##*/}"
    done
  fi

  { brew leaves; printf '%s\n' "$installed_casks"; } 2>/dev/null \
    | sed 's#.*/##' | grep -v '^$' | sort -u > "$tmp/installed"

  if extra="$(comm -13 "$tmp/declared" "$tmp/installed")" && [ -n "$extra" ]; then
    warn "installed but not in any Brewfile:"
    # shellcheck disable=SC2086  # word splitting is the point: one name per line
    printf '       %s\n' $extra
    warn "either add them to a Brewfile or 'brew uninstall' them"
  else
    ok "no undeclared packages"
  fi
fi

if [ "$bundle_failures" -gt 0 ]; then
  warn "Packages complete, with $bundle_failures bundle(s) reporting failures above"
else
  ok "Packages complete"
fi

# A partial apps/optional/local bundle should not invalidate the core machine,
# but a failed core bundle means required tools are missing. Return that fact to
# bootstrap.sh after diagnostics have run; bootstrap aggregates step failures
# so dotfiles, languages and editors still get their chance to complete.
[ "$core_bundle_failed" = "0" ]
