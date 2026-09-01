#!/usr/bin/env bash
# Shared helpers. Sourced by every script in this directory.
#
# Written for bash 3.2 — the version macOS ships — because bootstrap runs
# before Homebrew's modern bash exists. No associative arrays, no `readarray`.

# Guard against double-sourcing.
[ -n "${MACSTRAP_LIB_LOADED:-}" ] && return 0
MACSTRAP_LIB_LOADED=1

MACSTRAP_ROOT="${MACSTRAP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export MACSTRAP_ROOT

DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

# --- Output ---------------------------------------------------------------
# Colour only when stdout is a terminal, so logs and CI output stay clean.
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BLUE=$'\033[34m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'
else
  C_RESET=; C_DIM=; C_BLUE=; C_GREEN=; C_YELLOW=; C_RED=; C_BOLD=
fi

log()   { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip()  { printf '%s  --%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
warn()  { printf '%s  !!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '%serror%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
header() { printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- Execution ------------------------------------------------------------
# run <cmd> [args...] — honours DRY_RUN. Arguments are passed through as an
# array, never re-parsed by a shell, so paths with spaces survive.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s  would run:%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  "$@"
}

# confirm <prompt> — returns 0 for yes. Auto-yes under --yes, and auto-no when
# there is no terminal to ask on (so an unattended run never hangs).
confirm() {
  [ "$ASSUME_YES" = "1" ] && return 0
  [ -t 0 ] || { warn "not a terminal, assuming no: $1"; return 1; }
  printf '%s  ?? %s%s [y/N] ' "$C_YELLOW" "$1" "$C_RESET"
  read -r reply
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# --- Filesystem -----------------------------------------------------------
# backup <path> — move an existing file/dir aside with a timestamp suffix.
# Uses BSD `date` syntax; these scripts are macOS-only by design.
backup() {
  local target="$1"
  [ -e "$target" ] || [ -L "$target" ] || return 0

  # Second resolution is not enough: two links replaced in the same second
  # would collide, and `mv` onto an existing directory nests instead of
  # failing. Find a free name rather than trusting the timestamp.
  local stamp dest n=0
  stamp="$(date +%Y%m%d-%H%M%S)"
  dest="$target.bak-$stamp"
  while [ -e "$dest" ] || [ -L "$dest" ]; do
    n=$((n + 1))
    dest="$target.bak-$stamp.$n"
  done

  warn "backing up $target -> $dest"
  run mv "$target" "$dest"
}

# link <source-in-repo> <destination> — idempotent symlink.
#
# Symlinks rather than copies, so editing the file in the repo takes effect
# immediately and `git status` shows drift. The exception is anything holding
# an identity or a secret; those get copied from a template instead.
link() {
  local src="$MACSTRAP_ROOT/$1" dst="$2"
  [ -e "$src" ] || die "missing source file: $src"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    skip "$dst already linked"
    return 0
  fi

  backup "$dst"
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
  ok "linked $dst -> $src"
}

# --- Guards ---------------------------------------------------------------
require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "macstrap is macOS-only (found $(uname -s))"
}

# Refuse to run as root. Homebrew flatly rejects it, and anything this script
# writes as root leaves files the real user cannot edit afterwards.
refuse_root() {
  [ "$(id -u)" != "0" ] || die "do not run macstrap with sudo; it will ask when it needs to"
}

brew_prefix() {
  if [ -x /opt/homebrew/bin/brew ]; then echo /opt/homebrew
  elif [ -x /usr/local/bin/brew ]; then echo /usr/local
  else return 1
  fi
}

# The expected prefix for this architecture, whether or not brew exists yet.
# Needed by --dry-run on a machine that has no Homebrew: the real prefix cannot
# be probed, but the actions that depend on it still have to be printable.
brew_prefix_expected() {
  [ "$(uname -m)" = "arm64" ] && echo /opt/homebrew || echo /usr/local
}

# Put Homebrew on PATH for the current process.
#
# bootstrap.sh runs each step in its own `bash` child, so the `brew shellenv`
# evaluated inside homebrew.sh dies with that child. On an already-provisioned
# machine this is invisible — brew is on PATH from ~/.zprofile — but on a
# genuinely fresh Mac every step after homebrew.sh would inherit the original
# pre-Homebrew PATH and fail. Every dependent script calls this.
activate_homebrew() {
  have brew && return 0
  local prefix
  prefix="$(brew_prefix)" || return 1
  eval "$("$prefix/bin/brew" shellenv)"

  # rustup is keg-only (it conflicts with the `rust` formula), so Homebrew
  # never symlinks it into bin/. Without this, `cargo` and `rustup` are absent
  # even though the formula installed fine.
  [ -d "$prefix/opt/rustup/bin" ] && export PATH="$prefix/opt/rustup/bin:$PATH"
  return 0
}
