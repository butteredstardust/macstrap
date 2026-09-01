#!/usr/bin/env bash
#
#   macstrap — provision a macOS development machine.
#
#   ./bootstrap.sh                      preflight, homebrew, packages, dotfiles,
#                                       languages, editors
#   ./bootstrap.sh --dry-run            print every action, change nothing
#   ./bootstrap.sh --yes                never prompt
#   ./bootstrap.sh --with-optional      also install Brewfile.optional
#   ./bootstrap.sh --with-macos-defaults  also apply system preferences
#   ./bootstrap.sh --only dotfiles,editors
#   ./bootstrap.sh --list
#
# Every step is idempotent: running this twice is safe and the second run is
# mostly no-ops. Read scripts/macos-defaults.sh before enabling it — it is the
# only step that touches settings outside your home directory.
set -euo pipefail

MACSTRAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MACSTRAP_ROOT
. "$MACSTRAP_ROOT/scripts/lib.sh"

# Step name -> script. Order matters: each depends on the ones before it.
STEPS="preflight homebrew packages dotfiles languages editors"
OPTIONAL_STEPS="macos-defaults"

usage() { sed -n '2,20p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0; }

only=""
with_macos_defaults=0
export WITH_OPTIONAL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)             export DRY_RUN=1 ;;
    -y|--yes)              export ASSUME_YES=1 ;;
    --with-optional)       export WITH_OPTIONAL=1 ;;
    --with-macos-defaults) with_macos_defaults=1 ;;
    --only)                only="${2:-}"; shift ;;
    --only=*)              only="${1#*=}" ;;
    --list)                echo "steps: $STEPS"; echo "optional: $OPTIONAL_STEPS"; exit 0 ;;
    -h|--help)             usage ;;
    *)                     die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

if [ -n "$only" ]; then
  # Comma-separated selection, validated against the known step names so a typo
  # fails loudly instead of silently doing nothing.
  requested="$(echo "$only" | tr ',' ' ')"
  for step in $requested; do
    case " $STEPS $OPTIONAL_STEPS " in
      *" $step "*) ;;
      *) die "unknown step: $step (try --list)" ;;
    esac
  done
  run_steps="$requested"
else
  run_steps="$STEPS"
  [ "$with_macos_defaults" = "1" ] && run_steps="$run_steps macos-defaults"
fi

printf '%s' "$C_BOLD"
cat <<'BANNER'
                       _
  _ __  __ _ __ ___ __| |_ _ _ __ _ _ __
 | '  \/ _` / _(_-</ _|  _| '_/ _` | '_ \
 |_|_|_\__,_\__/__/\__|\__|_| \__,_| .__/
                                   |_|
BANNER
printf '%s' "$C_RESET"
log "repo:    $MACSTRAP_ROOT"
log "steps:   $run_steps"
[ "${DRY_RUN:-0}" = "1" ] && warn "DRY RUN — nothing will be changed"

started="$(date +%s)"

for step in $run_steps; do
  script="$MACSTRAP_ROOT/scripts/$step.sh"
  [ -f "$script" ] || die "missing script: $script"
  # Each step runs in its own bash so a `set -e` abort inside one is contained
  # and reported here with its name, rather than dying anonymously.
  if ! bash "$script"; then
    die "step failed: $step"
  fi
done

header "Done in $(( $(date +%s) - started ))s"
cat <<'NEXT'
Next:
  1. exec zsh                 pick up the new shell config
  2. scripts/doctor.sh        verify the result
  3. gh auth login            authenticate the GitHub CLI
  4. ssh-keygen -t ed25519    create a signing/auth key, then add it to GitHub

Machine-local secrets and paths go in ~/.zshrc.local and ~/.zshenv.local.
Neither is tracked by this repo.
NEXT
