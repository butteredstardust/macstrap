# 09 — macOS defaults

`scripts/macos-defaults.sh` is **opt-in**. It is the only step that changes settings outside your
home directory's dotfiles. It restarts Finder, Dock and SystemUIServer at the end, so the menu bar
blanks briefly and open Finder windows close. Save your work before running it.

```bash
./bootstrap.sh --only macos-defaults --dry-run   # read what it would do
./bootstrap.sh --with-macos-defaults
```

## How `defaults` works

Settings live in per-application plists. `defaults write` edits them. Each app reads its plist at
launch, so a change needs an app restart to take effect.

```bash
defaults read com.apple.dock autohide         # current value
defaults delete com.apple.dock autohide       # restore the system default
defaults read com.apple.finder                # everything in one domain
```

**A single `defaults delete` reverses every line in the script.** Nothing is destroyed, and no file
is overwritten.

## What is set, and why

The script records the settings of the machine this repo provisions. It sets only keys that differ
from the macOS default. A key left at the default is absent, so `defaults read` and the script agree.

### Finder

| Key | Effect |
|---|---|
| `AppleShowAllExtensions` | show file extensions. The default hides them, making `report.txt` and `report.txt.app` look alike |
| `ShowPathbar` | show the path of the current folder |
| `FXPreferredViewStyle = Nlsv` | use list view by default |
| `FXDefaultSearchScope = SCcf` | search the current folder, not the whole Mac |
| `DSDontWriteNetworkStores` / `USBStores` | stop scattering `.DS_Store` onto shares and USB sticks |

### Keyboard and text

| Key | Effect |
|---|---|
| `NSAutomaticSpellingCorrectionEnabled = false` | no autocorrect in native text fields |
| `WebAutomaticSpellingCorrectionEnabled = false` | no autocorrect in web views |
| `NSAutomaticCapitalizationEnabled = false` | stop capitalising the first word, which breaks typed commands |
| `NSAutomaticInlinePredictionEnabled = false` | no inline word predictions |

### Appearance and Dock

| Key | Effect |
|---|---|
| `AppleInterfaceStyle = Dark` | dark mode |
| `orientation = left` | Dock on the left edge. A side Dock costs less of a wide screen |
| `autohide = true` | hide the Dock until the pointer reaches it |
| `tilesize = 39`, `magnification = true`, `largesize = 54` | small icons that grow under the pointer |

### Trackpad and windows

| Key | Effect |
|---|---|
| `Clicking = true` | tap to click. Set in both trackpad domains: built-in and Bluetooth |
| `EnableTiledWindowMargins = false` | tile windows edge to edge, with no gap |

### Left at the macOS default

These are common changes this machine does not make. Add a line to the script to set one.

| Key | macOS default |
|---|---|
| `NSAutomaticQuoteSubstitutionEnabled`, `NSAutomaticDashSubstitutionEnabled` | on: `"` becomes a curly quote, `--` becomes `—` |
| `KeyRepeat`, `InitialKeyRepeat`, `ApplePressAndHoldEnabled` | Settings slider speeds; holding a key opens the accent picker |
| `AppleShowAllFiles` | dotfiles hidden in Finder. `⇧⌘.` toggles them |
| `com.apple.swipescrolldirection` | "natural" scrolling |
| `com.apple.screencapture location` | screenshots on the Desktop |

## Not automated on purpose

| Setting | Why manual |
|---|---|
| FileVault | generates a recovery key you must record yourself |
| Touch ID for `sudo` | edits `/etc/pam.d/sudo_local`, a system file; wrong content can lock you out |
| Login items | entirely personal |
| Hostname | identifying. Set it yourself: `sudo scutil --set ComputerName <name>` |
| Firewall | not reliably on by default. Check and enable it: **System Settings → Network → Firewall** |

## Reverting the whole script

There is no `--revert` flag. A blanket revert would also undo settings you changed by hand
afterwards. To undo one setting, run `defaults delete <domain> <key>` and restart the app. To undo
several, work through the tables above.
