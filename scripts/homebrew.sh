#!/usr/bin/env bash
# Install Homebrew and put it on PATH for the rest of this run.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Homebrew"

if prefix="$(brew_prefix)"; then
  ok "Homebrew already installed at $prefix"
else
  log "Installing Homebrew"
  # The official installer. It asks for a sudo password once, to create
  # /opt/homebrew and chown it to you.
  if [ "$DRY_RUN" = "1" ]; then
    skip "would run the Homebrew install script"
  else
    # Homebrew treats NONINTERACTIVE as set-or-unset, not 1-or-0, so exporting
    # it as "0" would still suppress the prompts. Only set it under --yes.
    if [ "$ASSUME_YES" = "1" ]; then
      NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  fi
  if [ "$DRY_RUN" = "1" ]; then
    # Nothing was installed, so there is no binary to probe. Use the
    # architecture's expected prefix so the remaining steps stay printable
    # instead of dying on a fresh machine.
    prefix="$(brew_prefix_expected)"
  else
    prefix="$(brew_prefix)" || die "Homebrew install did not produce a brew binary"
    ok "Homebrew installed at $prefix"
  fi
fi

# Make brew usable for the remainder of THIS script. Note that bootstrap.sh
# runs each step in its own child process, so this does not reach the next
# step — every dependent script calls activate_homebrew itself.
if [ "$DRY_RUN" != "1" ]; then
  activate_homebrew || die "brew installed but not activatable at $prefix"

  # Analytics are on by default and phone home per command.
  if [ "$(brew analytics 2>/dev/null | head -1)" != "InfluxDB analytics are disabled." ]; then
    log "Disabling Homebrew analytics"
    brew analytics off
  fi

  log "Updating formula definitions"
  brew update

  ok "Homebrew ready ($(brew --version 2>/dev/null | head -1))"
else
  skip "would disable analytics and run: brew update"
  ok "Homebrew step complete (dry run, prefix $prefix)"
fi
