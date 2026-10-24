#!/usr/bin/env bash
# macOS system preferences.
#
# WARNING: this step restarts Finder, Dock and SystemUIServer at the end. The
# menu bar blanks briefly and open Finder windows close. Save your work first.
#
# This is the only script that changes settings outside your dotfiles. It is
# opt-in from bootstrap. Read it before running it.
#
# Every line is reversible. `defaults delete <domain> <key>` restores the system
# default for one key. Nothing on disk is removed or overwritten.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "macOS defaults"
require_macos

log "Some settings need administrator rights; you may be prompted once."

# --- Finder ---------------------------------------------------------------
# Show file extensions. The default hides them, so `.txt` and `.txt.rtf` look
# identical. That hides a downloaded file that is not what it claims to be.
run defaults write NSGlobalDomain AppleShowAllExtensions -bool true
run defaults write com.apple.finder ShowPathbar -bool true
run defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
run defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search this folder

# Keep .DS_Store files off network shares and USB sticks. They are harmless
# locally. They are noise in a shared or committed directory.
run defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
run defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# --- Keyboard & text ------------------------------------------------------
# Stop macOS rewriting what you type. Autocorrect and capitalisation change
# identifiers and commands typed into native text fields.
run defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
run defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false
run defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
run defaults write NSGlobalDomain NSAutomaticInlinePredictionEnabled -bool false

# --- Appearance -----------------------------------------------------------
run defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# --- Dock -----------------------------------------------------------------
# Dock on the left edge, hidden until needed. The screen is wider than it is
# tall, so a side Dock costs less space.
run defaults write com.apple.dock orientation -string "left"
run defaults write com.apple.dock autohide -bool true
run defaults write com.apple.dock tilesize -int 39
run defaults write com.apple.dock magnification -bool true
run defaults write com.apple.dock largesize -int 54

# --- Trackpad & windows ---------------------------------------------------
# Tap to click. Write both domains: the built-in and the Bluetooth trackpad
# read separate plists.
run defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Tile windows edge to edge, with no gap between them.
run defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

# --- Apply ----------------------------------------------------------------
if [ "$DRY_RUN" != "1" ]; then
  log "Restarting Finder, Dock and SystemUIServer to apply"
  for app in Finder Dock SystemUIServer; do
    killall "$app" >/dev/null 2>&1 || true
  done
fi

ok "macOS defaults applied"
warn "Some settings only take effect after logging out and back in."
