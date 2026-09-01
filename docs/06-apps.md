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

Some apps have no cask and only ship through the App Store. `mas` handles those, and the entries
live at the bottom of `Brewfile.optional`.

```
mas "Amphetamine", id: 937984704
```

**The catch:** you must be signed in to the App Store, and `mas` is the least reliable installer
here. Current `brew bundle` tries `mas install` and falls back to `mas get`, so a free app you have
never "bought" can usually still be acquired — but sign-in state, region availability, age rating
and App Store outages all still fail, and `brew bundle` exits non-zero for the whole file when one
entry does.

That is why the `mas` entries live in `Brewfile.optional`, and why `scripts/packages.sh` treats a
failure of that bundle as non-fatal. An App Store hiccup must not stop your dotfiles, toolchains and
editors from being set up — those steps all run after packages.

Find the id of an app you already have:

```bash
mdls -name kMDItemAppStoreAdamID -raw "/Applications/Amphetamine.app"
```

`mas` cannot install Safari extensions independently either; they arrive with their container app
(Hush, Dark Reader and uBlock Origin Lite are each a full App Store app).

## Apps installed outside Homebrew

Casks do not cover everything, and it is easy to accumulate hand-downloaded `.app` bundles that no
manifest knows about. Audit them:

```bash
brew info --cask --json=v2 $(brew list --cask | tr '\n' ' ') \
  | jq -r '.casks[].artifacts[]?.app[]?' | sort -u > /tmp/brew-apps
/bin/ls -1 /Applications ~/Applications 2>/dev/null | grep '\.app$' | sort -u > /tmp/all-apps
comm -23 /tmp/all-apps /tmp/brew-apps
```

Use `/bin/ls`, not `ls` — the alias in `.zshrc` maps it to `eza --long`, which returns a table
rather than bare names and silently breaks the diff.

For each result, decide:

| Result | Action |
|---|---|
| a cask exists | migrate it — see below. `--force` is a reinstall, not an adoption |
| App Store only | add a `mas` line |
| self-updating (Docker, Claude, browsers) | cask it for the record; let it update itself |
| something you built yourself | leave it out of the Brewfiles entirely |
| you don't recognise it | that is the point of the audit |

### Migrating a hand-installed app to a cask

There is no "adopt" operation. `brew install --cask --force <name>` **overwrites the app bundle** with
Homebrew's copy — it does not bless the one already there. That is usually fine, because app *data*
lives in `~/Library/Application Support` and `~/Library/Preferences`, not in the bundle. But do it
deliberately:

```bash
brew info --cask <name>                    # check version and whether it auto-updates
# quit the app first — replacing a running bundle corrupts its state
brew install --cask --force <name>
brew list --cask --versions <name>         # confirm a receipt now exists
```

For App Store installs being switched to a cask, delete the MAS copy first; otherwise you have two
update mechanisms fighting over one bundle. **Pick one source per app and record which.** Hush and
The Unarchiver exist both ways, so they are exactly where this goes wrong.

### Self-updating apps

Claude, Tailscale and The Unarchiver declare `auto_updates true`. Homebrew skips these during a
normal `brew upgrade` — it compares bundle metadata and will not push its recorded version over a
newer installed one, so the "cask downgrades my app" worry is unfounded *unless* you use
`brew upgrade --greedy`, which explicitly overrides that behaviour.

Treat their cask entries as a **record of what belongs on the machine and where it came from**,
not as the thing that keeps them current. Avoid `--greedy` for them.

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

Three things make that comparison lie if you write it naively, and all three are handled:

| | |
|---|---|
| Tapped formulae print fully qualified (`oven-sh/bun/bun`) while Brewfile lines are bare | strip the tap prefix on **both** sides, or every tapped package reads as undeclared |
| Renamed casks appear under both tokens (`docker` *and* `docker-desktop`) | read the Caskroom and keep only real directories; the old token is a symlink |
| Untrusted taps are omitted from `brew leaves` altogether | the report under-counts silently — see "Tap trust" in `docs/11-troubleshooting.md` |

### `Brewfile.local`

Gitignored by `*.local`, installed and counted alongside the tracked bundles. It exists because the
only other way to silence the drift report is to publish the package name, and some names should not
be published — internal tooling, an employer's tap, a personal CLI. Without it, "keep the report
clean" and "keep the repo publishable" pull in opposite directions and the report loses.

It is also the honest place to park something you intend to remove but have not verified yet: a
commented `brew uninstall <x>` next to the line records the intent where you will see it again.

The cruft this guards against is real: the machine this repo was distilled from had a pinned
`icu4c@75` (a leaked transitive dependency), three overlapping Docker installs, and four editor AI
extensions competing for one inline-completion slot.
