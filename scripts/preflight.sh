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
# Provides git, clang, make and the SDK headers. Homebrew will not install
# without it. `xcode-select -p` succeeding is the reliable check; the GUI
# installer is asynchronous, so we wait rather than racing it.
if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode Command Line Tools present ($(xcode-select -p))"
else
  log "Installing Xcode Command Line Tools (a GUI dialog will open)"
  warn "--yes cannot skip this: the dialog and its admin prompt are Apple's, not ours"
  run xcode-select --install || true

  if [ "$DRY_RUN" != "1" ]; then
    # Bounded wait. Cancelling the dialog, losing the network, or an installer
    # error would otherwise leave this polling forever with no way to tell the
    # difference between "still downloading" and "never going to finish".
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
# Only needed for the occasional x86-only binary. Cheap to install, annoying
# to discover missing halfway through a build.
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
# Not installed by this script — it needs a recovery key you must record
# yourself — but a dev machine without full-disk encryption is worth flagging.
if ! fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
  warn "FileVault is OFF. Enable it: System Settings > Privacy & Security."
fi

ok "Preflight complete"
