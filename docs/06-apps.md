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
| Ghostty | terminal. See `docs/04-terminal.md` |
| Visual Studio Code | primary editor |
| Docker Desktop | containers. Install exactly one Docker, see `docs/05-languages.md` |
| Google Chrome | devtools and browser automation. Not necessarily the default browser |

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
| Applite | GUI over Homebrew casks. Useful for browsing. `brew` remains the source of truth |
| balenaEtcher | flashing SD cards and USB images |
| Cyberduck | SFTP/S3 browser |
| TextMate | fast plain-text editor for files too big or too trivial for VS Code |

## Mac App Store

Some apps have no cask and ship only through the App Store. `mas` installs those. Its entries live at
the bottom of `Brewfile.optional`.

```
mas "Amphetamine", id: 937984704
```

**Sign in to the App Store first.** `mas` is the least reliable installer here. `brew bundle` tries
`mas install` and falls back to `mas get`, so a free app you never "bought" usually still installs.
Sign-in state, region availability, age rating and App Store outages each still fail. One failed
entry makes `brew bundle` exit non-zero for the whole file.

So the `mas` entries live in `Brewfile.optional`, and `scripts/packages.sh` treats a failure of that
bundle as non-fatal. Dotfiles, toolchains and editors all run after packages, and an App Store hiccup
must not stop them.

Find the id of an app you already have:

```bash
mdls -name kMDItemAppStoreAdamID -raw "/Applications/Amphetamine.app"
```

`mas` cannot install Safari extensions on their own. Each arrives with its container app. Hush, Dark
Reader and uBlock Origin Lite are each a full App Store app.

## Apps installed outside Homebrew

Casks do not cover everything. Hand-downloaded `.app` bundles accumulate, and no manifest knows about
them. Audit them:

```bash
brew info --cask --json=v2 $(brew list --cask | tr '\n' ' ') \
  | jq -r '.casks[].artifacts[]?.app[]?' | sort -u > /tmp/brew-apps
/bin/ls -1 /Applications ~/Applications 2>/dev/null | grep '\.app$' | sort -u > /tmp/all-apps
comm -23 /tmp/all-apps /tmp/brew-apps
```

Use `/bin/ls`, not `ls`. The alias in `.zshrc` maps `ls` to `eza --long`, which returns a table
instead of bare names and breaks the diff silently.

For each result, decide:

| Result | Action |
|---|---|
| a cask exists | migrate it, see below. `--force` is a reinstall, not an adoption |
| App Store only | add a `mas` line |
| self-updating (Docker, Claude, browsers) | declare the cask for the record. Let the app update itself |
| something you built yourself | leave it out of the Brewfiles entirely |
| you don't recognise it | that is the point of the audit |

### Migrating a hand-installed app to a cask

Quit the app before starting. Replacing a running bundle corrupts its state.

Homebrew has no "adopt" operation. `brew install --cask --force <name>` **overwrites the app bundle**
with Homebrew's copy. It does not bless the bundle already there. That is usually fine: app *data*
lives in `~/Library/Application Support` and `~/Library/Preferences`, not in the bundle. Do it
deliberately:

```bash
brew info --cask <name>                    # check version and whether it auto-updates
brew install --cask --force <name>
brew list --cask --versions <name>         # confirm a receipt now exists
```

Switching an App Store install to a cask? Remove the MAS copy first. Otherwise two update mechanisms
fight over one bundle. **Pick one source per app, and record which.** Hush and The Unarchiver ship
both ways, so they are where this goes wrong.

### Self-updating apps

Claude, Tailscale and The Unarchiver declare `auto_updates true`. A normal `brew upgrade` skips them.
Homebrew compares bundle metadata and will not push its recorded version over a newer installed one.
`brew upgrade --greedy` overrides that behaviour, so avoid it for these apps.

Treat their cask entries as a **record of what belongs on the machine and where it came from**. They
are not what keeps those apps current.

## Keeping the Brewfiles honest

```bash
brew leaves                      # top-level formulae, no dependencies
brew list --cask
brew bundle dump --describe --force --file=/tmp/Brewfile.current
diff <(sort Brewfile) <(sort /tmp/Brewfile.current)
```

`scripts/packages.sh` runs this comparison at the end of every provisioning run. It reports anything
installed but undeclared, and never removes it. Uninstalling something unasked is not a provisioning
script's call.

Three things make a naive version of that comparison lie. The script handles all three:

| | |
|---|---|
| Tapped formulae print fully qualified (`oven-sh/bun/bun`) while Brewfile lines are bare | strip the tap prefix on **both** sides, or every tapped package reads as undeclared |
| Renamed casks appear under both tokens (`docker` *and* `docker-desktop`) | read the Caskroom and keep only real directories; the old token is a symlink |
| Untrusted taps are omitted from `brew leaves` altogether | the report under-counts silently — see "Tap trust" in `docs/11-troubleshooting.md` |

### `Brewfile.local`

Gitignored by `*.local`. Installed and counted alongside the tracked bundles.

Declare here anything you need but cannot publish: internal tooling, an employer's tap, a personal
CLI. Without this file, the only way to silence the drift report is to publish the package name. Then
"keep the report clean" and "keep the repo publishable" pull against each other, and the report
loses.

It is also the place to park a package you intend to remove but have not verified yet. Write a
commented `brew uninstall <x>` next to the line to record the intent where you will see it again.
