#!/usr/bin/env bash
# Preflight: verify the machine can be provisioned, and install the one
# dependency Homebrew itself needs (the Xcode Command Line Tools).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Preflight"

require_macos
refuse_root

log "macOS $(sw_vers -productVersion) on $(uname -m)"

if [ "$(uname -m)" != "arm64" ]; then
  warn "Intel Mac: Homebrew installs to /usr/local, not /opt/homebrew."
  warn "Everything here handles both, but casks may differ in availability."
fi

# --- Xcode Command Line Tools --------------------------------------------
# These provide git, clang, make and the SDK headers. Homebrew refuses to
# install without them. Check with `xcode-select -p`, the only reliable signal.
# The GUI installer runs asynchronously, so wait for it rather than racing it.
if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode Command Line Tools present ($(xcode-select -p))"
else
  log "Installing Xcode Command Line Tools (a GUI dialog will open)"
  warn "--yes cannot skip this: the dialog and its admin prompt are Apple's, not ours"
  run xcode-select --install || true

  if [ "$DRY_RUN" != "1" ]; then
    # Bound the wait. A cancelled dialog, a dropped network or an installer
    # error would otherwise poll forever, with no way to tell "still
    # downloading" from "never going to finish".
    printf '  waiting for the installer to finish (up to 30 min)'
    deadline=$(( $(date +%s) + 1800 ))
    until xcode-select -p >/dev/null 2>&1; do
      if [ "$(date +%s)" -ge "$deadline" ]; then
        printf '\n'
        die "Command Line Tools did not install within 30 minutes.
     Install them manually, then re-run:
       xcode-select --install
     Or download 'Command Line Tools for Xcode' from https://developer.apple.com/download/all/"
      fi
      printf '.'
      sleep 10
    done
    printf '\n'
    ok "Command Line Tools installed"
  fi
fi

# --- Rosetta 2 ------------------------------------------------------------
# Needed only for the occasional x86-only binary. Cheap to install, and
# annoying to discover missing halfway through a build.
if [ "$(uname -m)" = "arm64" ] && [ ! -d /usr/libexec/rosetta ]; then
  if confirm "Install Rosetta 2 (for x86-only binaries)?"; then
    run softwareupdate --install-rosetta --agree-to-license
  else
    skip "Rosetta 2"
  fi
else
  [ "$(uname -m)" = "arm64" ] && ok "Rosetta 2 present"
fi

# --- FileVault ------------------------------------------------------------
# This script leaves FileVault alone. It needs a recovery key you must record
# yourself. A dev machine without full-disk encryption is still worth flagging.
if ! fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
  warn "FileVault is OFF. Enable it: System Settings > Privacy & Security."
fi

ok "Preflight complete"
