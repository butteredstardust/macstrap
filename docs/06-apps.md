# 06 — Applications

Three bundles, so the core stays honest:

| File | Contents | Installed by default |
|---|---|---|
| `Brewfile` | CLI tools used daily | ✅ |
| `Brewfile.apps` | GUI tools for development | ✅ |
| `Brewfile.optional` | taste, media, "might want" | only with `--with-optional` |

```bash
brew bundle --file=Brewfile.apps
brew bundle --file=Brewfile.optional
```

## Development

| App | Role |
|---|---|
| Ghostty | terminal — see `docs/04-terminal.md` |
| Visual Studio Code | primary editor |
| Zed | fast second editor for large files and quick edits |
| Docker Desktop | containers — install only one Docker, see `docs/05-languages.md` |
| Google Chrome | devtools and browser automation, not necessarily the default browser |

## Utilities

| App | Role | Why not the built-in |
|---|---|---|
| Rectangle | keyboard window snapping | macOS tiling is mouse-driven and limited |
| Maccy | clipboard history | macOS has none |
| Swift Quit | ⌘W on the last window quits the app | matches every other OS's behaviour |
| Enpass | password manager, offline vault | Keychain does not sync outside Apple devices |

## Optional, and why it is optional

| App | Note |
|---|---|
| Pearcleaner | uninstaller that removes support files too. Dragging to Trash does not |
| QDirStat | graphical disk usage. `dust` covers the CLI case |
| Applite | GUI over Homebrew casks. Useful for browsing; `brew` remains the source of truth |
| balenaEtcher | flashing SD cards and USB images |
| Cyberduck | SFTP/S3 browser |
| TextMate | fast plain-text editor for files too big or too trivial for VS Code |

## Mac App Store

`mas` is in the core Brewfile so `brew bundle dump` can capture App Store apps. It cannot install an
app you have never purchased under the signed-in Apple ID — App Store apps stay out of the tracked
Brewfiles for that reason. If you want them, add them to a local `Brewfile.local`:

```
mas "Xcode", id: 497799835
```

## Keeping the Brewfiles honest

```bash
brew leaves                      # top-level formulae, no dependencies
brew list --cask
brew bundle dump --describe --force --file=/tmp/Brewfile.current
diff <(sort Brewfile) <(sort /tmp/Brewfile.current)
```

`scripts/packages.sh` runs this comparison at the end of every provisioning run and reports anything
installed but undeclared. It only reports — uninstalling something you did not ask it to is not a
provisioning script's call.

The cruft this guards against is real: the machine this repo was distilled from had a pinned
`icu4c@75` (a leaked transitive dependency), three overlapping Docker installs, and four AI CLIs
where one was in use.
