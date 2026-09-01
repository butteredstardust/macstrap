# 09 — macOS defaults

`scripts/macos-defaults.sh` is **opt-in**. It is the only step that changes settings outside your
home directory's dotfiles, and it restarts Finder, Dock and SystemUIServer at the end — the menu bar
blanks briefly and open Finder windows close.

```bash
./bootstrap.sh --only macos-defaults --dry-run   # read what it would do
./bootstrap.sh --with-macos-defaults
```

## How `defaults` works

Settings live in per-application plists. `defaults write` edits them; the app reads its plist at
launch, which is why a restart is needed.

```bash
defaults read com.apple.dock autohide         # current value
defaults delete com.apple.dock autohide       # restore the system default
defaults read com.apple.finder                # everything in one domain
```

**Every line in the script is reversible with a single `defaults delete`.** Nothing is destroyed,
and no file is overwritten.

## What is set, and why

### Finder

| Key | Effect |
|---|---|
| `AppleShowAllExtensions` | show file extensions — the default hides them, so `report.txt` vs `report.txt.app` is invisible |
| `AppleShowAllFiles` | show dotfiles |
| `ShowPathbar` / `ShowStatusBar` | where you are and how much is here |
| `FXPreferredViewStyle = Nlsv` | list view by default |
| `FXDefaultSearchScope = SCcf` | search the current folder, not the whole Mac |
| `DSDontWriteNetworkStores` / `USBStores` | stop scattering `.DS_Store` onto shares and sticks |

### Keyboard

| Key | Effect |
|---|---|
| `KeyRepeat = 2`, `InitialKeyRepeat = 15` | faster than the Settings slider allows |
| `ApplePressAndHoldEnabled = false` | holding a key repeats it instead of opening the accent picker. Required for vim, and for holding `j`/`l` anywhere |
| `NSAutomaticQuoteSubstitutionEnabled = false` | stop turning `"` into `"` — this silently corrupts code pasted into any native text field |
| `NSAutomaticDashSubstitutionEnabled = false` | stop turning `--` into `—`, which breaks pasted CLI flags |
| `AppleKeyboardUIMode = 3` | Tab reaches every control in a dialog, not just text fields |

The substitution settings are the highest-value entries here. They corrupt text in a way that looks
correct until a shell rejects it.

### Dock

`autohide` with zero delay, fixed Space order (`mru-spaces = false` — otherwise Spaces reorder
themselves and keyboard switching becomes unpredictable), no recents, minimize into the app icon.

### Screenshots

Saved to `~/Pictures/Screenshots` as PNG without the window drop shadow. The default dumps them on
the Desktop, and the shadow adds ~40px of transparent margin that ruins any screenshot pasted into
a document.

### Misc

| Key | Effect |
|---|---|
| `com.apple.swipescrolldirection = false` | non-"natural" scrolling; matches every external mouse |
| `NSDocumentSaveNewDocumentsToCloud = false` | save to disk, not iCloud, by default |
| `NSNavPanelExpandedStateForSaveMode` | save dialogs open expanded |
| `NSWindowResizeTime = 0.001` | windows resize instantly instead of animating |

## Not automated on purpose

| Setting | Why manual |
|---|---|
| FileVault | generates a recovery key you must record yourself |
| Touch ID for `sudo` | edits `/etc/pam.d/sudo_local`, a system file; wrong content can lock you out |
| Login items | entirely personal |
| Hostname | identifying. Set it yourself: `sudo scutil --set ComputerName <name>` |
| Firewall | on by default in recent macOS; verify rather than blindly re-set |

## Reverting the whole script

There is no `--revert` flag, because a blanket revert would also undo settings you changed by hand
afterwards. To undo a specific one, `defaults delete <domain> <key>` and restart the app. To undo
several, work through the table above.
