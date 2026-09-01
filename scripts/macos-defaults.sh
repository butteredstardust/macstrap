#!/usr/bin/env bash
# macOS system preferences.
#
# This is the only script that changes settings outside your home directory's
# dotfiles, so it is opt-in from bootstrap and worth reading before running.
#
# Everything here is reversible: `defaults delete <domain> <key>` restores the
# system default for any single line, and nothing is deleted or overwritten on
# disk. It does restart Finder, Dock and SystemUIServer at the end, which will
# briefly blank the menu bar and close Finder windows.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "macOS defaults"
require_macos

log "Some settings need administrator rights; you may be prompted once."

# --- Finder ---------------------------------------------------------------
# Show file extensions. The default hides them, which makes `.txt` vs `.txt.rtf`
# invisible and is a real footgun when a downloaded file is not what it claims.
run defaults write NSGlobalDomain AppleShowAllExtensions -bool true
run defaults write com.apple.finder AppleShowAllFiles -bool true          # dotfiles
run defaults write com.apple.finder ShowPathbar -bool true
run defaults write com.apple.finder ShowStatusBar -bool true
run defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
run defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search this folder
run defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Do not scatter .DS_Store files onto network shares and USB sticks. Purely
# cosmetic locally; genuinely annoying in a shared or committed directory.
run defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
run defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# --- Keyboard -------------------------------------------------------------
# Fast key repeat. KeyRepeat=1 is faster than the Settings slider allows.
run defaults write NSGlobalDomain KeyRepeat -int 2
run defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Hold-a-key must repeat, not open the accent picker. Non-negotiable in vim,
# and in any editor where you hold j or l.
run defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Disable "smart" substitutions: they turn straight quotes into curly ones and
# `--` into an em dash, which silently corrupts code pasted into any text field.
run defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
run defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
run defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
run defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Full keyboard access: Tab moves between every control in a dialog, not just
# text fields.
run defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# --- Dock -----------------------------------------------------------------
run defaults write com.apple.dock autohide -bool true
run defaults write com.apple.dock autohide-delay -float 0        # no hover delay
run defaults write com.apple.dock autohide-time-modifier -float 0.15
run defaults write com.apple.dock tilesize -int 48
run defaults write com.apple.dock show-recents -bool false
run defaults write com.apple.dock mru-spaces -bool false         # keep Space order fixed
run defaults write com.apple.dock minimize-to-application -bool true

# --- Screenshots ----------------------------------------------------------
# Out of the Desktop and into a folder, with no drop shadow on window captures.
run mkdir -p "$HOME/Pictures/Screenshots"
run defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
run defaults write com.apple.screencapture type -string "png"
run defaults write com.apple.screencapture disable-shadow -bool true

# --- Trackpad & UI --------------------------------------------------------
run defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false  # non-"natural"
run defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"
run defaults write NSGlobalDomain NSWindowResizeTime -float 0.001             # instant windows
run defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
run defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

# Save to disk by default, not iCloud.
run defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# --- Safety ---------------------------------------------------------------
# Crash reporter dialogs interrupt long builds; notification-only is enough.
run defaults write com.apple.CrashReporter UseUNC -int 1

# --- Apply ----------------------------------------------------------------
if [ "$DRY_RUN" != "1" ]; then
  log "Restarting Finder, Dock and SystemUIServer to apply"
  for app in Finder Dock SystemUIServer; do
    killall "$app" >/dev/null 2>&1 || true
  done
fi

ok "macOS defaults applied"
warn "Some settings only take effect after logging out and back in."
