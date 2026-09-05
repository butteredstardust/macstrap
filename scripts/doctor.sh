#!/usr/bin/env bash
# Read-only health check. Changes nothing; exits non-zero if something is off.
#
#   scripts/doctor.sh
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Doctor"

# Check the PATH the provisioning scripts see, not the interactive shell's.
# Otherwise doctor passes on a machine where bootstrap fails.
activate_homebrew || warn "Homebrew not found"

failures=0
check() {  # check <label> <command...>
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$label"
  else
    warn "$label"
    failures=$((failures + 1))
  fi
}

# --- Base -----------------------------------------------------------------
check "Xcode Command Line Tools" xcode-select -p
check "Homebrew"                 command -v brew
check "zsh is the login shell"   test "$(basename "${SHELL:-}")" = "zsh"

# --- Tools ----------------------------------------------------------------
for tool in git gh jq fd rg bat eza starship node pnpm bun uv rustup; do
  check "$tool" command -v "$tool"
done

# --- Dotfiles -------------------------------------------------------------
for pair in \
  "$HOME/.zshrc:dotfiles/zsh/zshrc" \
  "$HOME/.zshenv:dotfiles/zsh/zshenv" \
  "$HOME/.zprofile:dotfiles/zsh/zprofile" \
  "$HOME/.config/ghostty/config:dotfiles/ghostty/config" \
  "$HOME/.config/starship.toml:dotfiles/starship/starship.toml"
do
  dst="${pair%%:*}"; src="${pair#*:}"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$MACSTRAP_ROOT/$src" ]; then
    ok "$dst -> $src"
  else
    warn "$dst is not linked to this repo"
    failures=$((failures + 1))
  fi
done

# --- Git identity ---------------------------------------------------------
if git config --global user.email >/dev/null 2>&1; then
  email="$(git config --global user.email)"
  ok "git identity: $(git config --global user.name) <$email>"
  case "$email" in
    *users.noreply.github.com) ;;
    *) warn "git email is a real address; every pushed commit publishes it" ;;
  esac
else
  warn "git user.email is unset"
  failures=$((failures + 1))
fi

# --- Fonts ----------------------------------------------------------------
# Glob instead of `ls | grep`. Font filenames hold spaces, and this setup
# aliases `ls` to eza.
font_found=0
for dir in "$HOME/Library/Fonts" /Library/Fonts; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*JetBrainsMono*; do
    [ -e "$f" ] && { font_found=1; break 2; }
  done
done

if [ "$font_found" = "1" ]; then
  ok "JetBrainsMono Nerd Font installed"
else
  warn "JetBrainsMono Nerd Font missing — ghostty and starship glyphs will render as boxes"
  failures=$((failures + 1))
fi

# --- Shell startup cost ---------------------------------------------------
# A slow shell is almost always a plugin doing work at load time. Bisect
# anything over half a second.
#
# Time this with bash's `time` builtin, not `date`. BSD date has no %N, so
# arithmetic on it resolves whole seconds only.
if have zsh; then
  elapsed="$( { TIMEFORMAT=%R; time zsh -i -c exit; } 2>&1 | tail -1 )"
  # %R is "0.412". Convert to integer milliseconds by splitting on the dot;
  # there is no bc here and BSD tools give no better option.
  secs="${elapsed%%.*}"; frac="${elapsed#*.}"
  ms=$(( 10#${secs:-0} * 1000 + 10#${frac:-0} ))
  if [ "$ms" -lt 500 ]; then
    ok "interactive zsh startup ${ms}ms"
  else
    warn "interactive zsh startup ${ms}ms — over 500ms, see docs/11-troubleshooting.md"
    failures=$((failures + 1))
  fi
fi

printf '\n'
if [ "$failures" -eq 0 ]; then
  ok "all checks passed"
else
  die "$failures check(s) failed"
fi
