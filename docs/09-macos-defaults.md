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

### Finder

| Key | Effect |
|---|---|
| `AppleShowAllExtensions` | show file extensions. The default hides them, making `report.txt` and `report.txt.app` look alike |
| `AppleShowAllFiles` | show dotfiles |
| `ShowPathbar` / `ShowStatusBar` | show where you are and how much is here |
| `FXPreferredViewStyle = Nlsv` | use list view by default |
| `FXDefaultSearchScope = SCcf` | search the current folder, not the whole Mac |
| `DSDontWriteNetworkStores` / `USBStores` | stop scattering `.DS_Store` onto shares and USB sticks |

### Keyboard

| Key | Effect |
|---|---|
| `KeyRepeat = 2`, `InitialKeyRepeat = 15` | faster than the Settings slider allows |
| `ApplePressAndHoldEnabled = false` | hold a key to repeat it, instead of opening the accent picker. Required for vim, and for holding `j` or `l` anywhere |
| `NSAutomaticQuoteSubstitutionEnabled = false` | stop turning `"` into `"`. That corrupts code pasted into any native text field |
| `NSAutomaticDashSubstitutionEnabled = false` | stop turning `--` into `—`, which breaks pasted CLI flags |
| `AppleKeyboardUIMode = 3` | Tab reaches every control in a dialog, not just text fields |

The two substitution settings are the highest-value entries here. They corrupt text in a way that
looks correct until a shell rejects it.

### Dock

Autohide with zero delay. Fixed Space order via `mru-spaces = false`, so Spaces stop reordering
themselves and keyboard switching stays predictable. No recents. Minimize into the app icon.

### Screenshots

Saved to `~/Pictures/Screenshots` as PNG, without the window drop shadow. The default dumps them on
the Desktop. The shadow adds ~40px of transparent margin that ruins any screenshot pasted into a
document.

### Misc

| Key | Effect |
|---|---|
| `com.apple.swipescrolldirection = false` | non-"natural" scrolling. Matches every external mouse |
| `NSDocumentSaveNewDocumentsToCloud = false` | save to disk by default, not iCloud |
| `NSNavPanelExpandedStateForSaveMode` | open save dialogs expanded |
| `NSWindowResizeTime = 0.001` | resize windows instantly instead of animating |

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
