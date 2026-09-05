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

# Brewfile.local is yours: gitignored, never published. Declare packages there
# that you depend on but cannot publish — a personal CLI, an employer's internal
# tool, a tap you are not going to explain. Without it, the only way to silence
# the drift report below is to publish the package name.
[ -f "$MACSTRAP_ROOT/Brewfile.local" ] && bundles="$bundles Brewfile.local"

# --- Tap trust ------------------------------------------------------------
# Homebrew refuses to load formulae from a third-party tap until you trust it:
#   Error: Refusing to load formula oven-sh/bun/bun from untrusted tap
#
# `brew bundle` inherits that refusal. On a fresh machine every tapped package
# then fails and the step exits non-zero. There is no Brewfile syntax for this,
# on purpose: trusting a tap means agreeing to run its maintainers' Ruby.
#
# So ask rather than trusting silently. Answering no is a valid choice; the
# tapped packages simply will not install.
#
# `brew trust` has no subcommand to query what is already trusted, so read its
# state file. Location per `brew trust --help`: $XDG_CONFIG_HOME/homebrew when
# that variable is set, ~/.homebrew otherwise.
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  trust_file="$XDG_CONFIG_HOME/homebrew/trust.json"
else
  trust_file="$HOME/.homebrew/trust.json"
fi

taps="$(sed -nE 's/^[[:space:]]*tap "([^"]*)".*/\1/p' "$MACSTRAP_ROOT"/Brewfile* 2>/dev/null | sort -u)"
for tap in $taps; do
  # The pattern omits the closing quote on purpose. A tap can be trusted
  # wholesale ("oven-sh/bun") or one formula at a time ("minio/stable/mc"), as
  # `brew trust` itself recommends. Matching the exact tap string would nag
  # about a tap whose every package you already trusted individually.
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
  # --no-upgrade leaves already-installed formulae at their current version.
  # Upgrading is topgrade's job, not provisioning's.
  #
  # Pass no --no-lock flag. `brew bundle` has no lockfile concept and rejects
  # the flag outright with `Error: invalid option`.
  #
  # No bundle may abort the run. The reasons differ per file:
  #
  # Brewfile.optional holds the `mas` entries. One App Store problem — signed
  # out, wrong region, an app never associated with the Apple ID — makes brew
  # bundle exit non-zero.
  #
  # Brewfile.apps holds casks that ship a .pkg and shell out to `sudo`, such as
  # Tailscale. Those cannot install unattended, because `sudo` needs a terminal.
  # They fail under `--yes`, over ssh and from CI whatever the Brewfile line
  # says. `--adopt` cannot claim them either, once the vendor's own download is
  # already installed.
  #
  # Aborting here would skip the drift report at the bottom. That report is the
  # one part of this step telling you what is actually on the machine.
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

# A running app only sees a new font after it reloads the font list. macOS
# refreshes the cache on its own, but not always before the next launch.
if [ "$DRY_RUN" != "1" ]; then
  for _font_cask in "$(brew --prefix)"/Caskroom/font-*; do
    [ -e "$_font_cask" ] || break     # unmatched glob stays literal in bash
    ok "fonts installed — restart running terminals to pick them up"
    break
  done
fi

# --- Drift report ---------------------------------------------------------
# Report anything installed by hand and never declared. Report only, never
# remove: uninstalling a package unasked is not a provisioning script's call.
if [ "$DRY_RUN" != "1" ]; then
  log "Checking for packages installed outside the Brewfiles"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # Use -E (ERE). BSD sed's basic regex has no `\|` alternation, so a BRE
  # version matches nothing and reports every package as undeclared.
  # The trailing `s#.*/##` strips the tap prefix from e.g. oven-sh/bun/bun.
  #
  # Concatenate only the bundles that exist. Brewfile.optional is documented as
  # "remove freely", and under `set -o pipefail` a missing file would abort the
  # whole step instead of degrading.
  existing=""
  for b in Brewfile Brewfile.apps Brewfile.optional Brewfile.local; do
    [ -f "$MACSTRAP_ROOT/$b" ] && existing="$existing $MACSTRAP_ROOT/$b"
  done

  # shellcheck disable=SC2086  # word splitting is the point here
  cat $existing \
    | sed -nE 's/^[[:space:]]*(brew|cask) "([^"]*)".*/\2/p' \
    | sed 's#.*/##' | sort -u > "$tmp/declared"

  # Strip the tap prefix on this side too. `brew leaves` prints tapped formulae
  # fully qualified (oven-sh/bun/bun) while the Brewfile side is already bare.
  # Without this, every tapped package reports as undeclared.
  #
  # Note that `brew leaves` omits untrusted taps entirely, so this report
  # under-counts rather than over-counts while a tap is untrusted.
  #
  # Read the Caskroom instead of `brew list --cask`. Homebrew keeps a renamed
  # cask's old token working forever through a Caskroom symlink, and
  # `brew list --cask` prints BOTH names. `docker` and `docker-desktop` are one
  # 2.3GB install, not two. The old token can never be declared either, because
  # `brew install docker` resolves to the new one. Keeping only real
  # directories yields the canonical name exactly once.
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

# A partial apps, optional or local bundle leaves the core machine valid. A
# failed core bundle means required tools are missing. Report that to
# bootstrap.sh after the diagnostics run. bootstrap aggregates step failures, so
# dotfiles, languages and editors still get their chance to complete.
[ "$core_bundle_failed" = "0" ]
