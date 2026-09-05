#!/usr/bin/env bash
# Shared helpers. Sourced by every script in this directory.
#
# Target bash 3.2, the version macOS ships. Bootstrap runs before Homebrew's
# modern bash exists. So: no associative arrays, no `readarray`.

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
# run <cmd> [args...] — honours DRY_RUN. Passes arguments through as an array.
# No shell re-parses them, so paths with spaces survive.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s  would run:%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  "$@"
}

# confirm <prompt> — returns 0 for yes. Answers yes under --yes. Answers no
# when there is no terminal to ask on, so an unattended run never hangs.
confirm() {
  [ "$ASSUME_YES" = "1" ] && return 0
  [ -t 0 ] || { warn "not a terminal, assuming no: $1"; return 1; }
  printf '%s  ?? %s%s [y/N] ' "$C_YELLOW" "$1" "$C_RESET"
  read -r reply
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# --- Filesystem -----------------------------------------------------------
# backup <path>            — move the file aside. Use before REPLACING it.
# backup_copy <path>       — copy it aside. Use before EDITING IT IN PLACE.
#
# WARNING: confusing these two loses data. A merge that runs `backup` first
# finds nothing to merge into, then writes only the new content.
#
# Ask: does the next step still need to read this file? If yes, use backup_copy.
backup_copy() {
  local target="$1"
  [ -f "$target" ] || return 0
  local dest
  dest="$(_backup_dest "$target")"
  warn "backing up $target -> $dest"
  run cp -p "$target" "$dest"
}

# Shared naming for both helpers. Second resolution is not enough: two files
# handled in the same second collide, and `mv` onto an existing directory nests
# instead of failing. So find a free name rather than trusting the timestamp.
_backup_dest() {
  local target="$1" stamp dest n=0
  stamp="$(date +%Y%m%d-%H%M%S)"
  dest="$target.bak-$stamp"
  while [ -e "$dest" ] || [ -L "$dest" ]; do
    n=$((n + 1))
    dest="$target.bak-$stamp.$n"
  done
  printf '%s\n' "$dest"
}

backup() {
  local target="$1"
  [ -e "$target" ] || [ -L "$target" ] || return 0

  local dest
  dest="$(_backup_dest "$target")"
  warn "backing up $target -> $dest"
  run mv "$target" "$dest"
}

# link <source-in-repo> <destination> — idempotent symlink.
#
# Symlink rather than copy, so editing the repo file takes effect immediately
# and `git status` shows drift. Files holding an identity or a secret are the
# exception; render those from a template instead.
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

# Refuse to run as root. Homebrew rejects it outright, and anything written as
# root leaves files the real user cannot edit afterwards.
refuse_root() {
  [ "$(id -u)" != "0" ] || die "do not run macstrap with sudo; it will ask when it needs to"
}

brew_prefix() {
  if [ -x /opt/homebrew/bin/brew ]; then echo /opt/homebrew
  elif [ -x /usr/local/bin/brew ]; then echo /usr/local
  else return 1
  fi
}

# Report the expected prefix for this architecture, whether or not brew exists.
# --dry-run needs this on a machine with no Homebrew: nothing can probe the real
# prefix, yet the actions depending on it must still print.
brew_prefix_expected() {
  [ "$(uname -m)" = "arm64" ] && echo /opt/homebrew || echo /usr/local
}

# Put Homebrew on PATH for the current process. Every dependent script calls
# this before using brew.
#
# bootstrap.sh runs each step in its own `bash` child, so the `brew shellenv`
# evaluated inside homebrew.sh dies with that child. A provisioned machine hides
# this, because ~/.zprofile already puts brew on PATH. On a fresh Mac, every step
# after homebrew.sh would otherwise inherit the pre-Homebrew PATH and fail.
activate_homebrew() {
  local prefix
  if have brew; then
    prefix="$(brew --prefix)" || return 1
  elif ! prefix="$(brew_prefix)"; then
    # A dry run on a fresh Mac reaches here, and that is not an error.
    # homebrew.sh only *printed* what it would do, so no brew binary exists.
    # This is also the one machine where previewing the rest of the run matters.
    #
    # Return 1 here and packages.sh calls `die`, which bootstrap.sh treats as
    # fatal. `./bootstrap.sh --dry-run` then stops after the Homebrew step and
    # previews nothing else.
    #
    # Succeeding is safe. Under DRY_RUN every brew invocation goes through
    # `run`, which prints instead of executing. The two callers that shell out
    # to brew directly — the Caskroom scan and the drift report in packages.sh
    # — already sit inside `if [ "$DRY_RUN" != "1" ]` blocks.
    if [ "${DRY_RUN:-0}" = "1" ]; then
      skip "Homebrew absent; previewing as though it had just been installed"
      return 0
    fi
    return 1
  else
    eval "$("$prefix/bin/brew" shellenv)"
  fi

  # rustup is keg-only, because it conflicts with the `rust` formula. Homebrew
  # therefore does not symlink its binaries into bin/, except `rustup` itself.
  # Without this line `cargo` is absent while the formula is installed and
  # `rustup` answers normally, which is a misleading way to fail.
  [ -d "$prefix/opt/rustup/bin" ] && export PATH="$prefix/opt/rustup/bin:$PATH"
  return 0
}
