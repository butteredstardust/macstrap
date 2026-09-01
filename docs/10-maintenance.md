# 10 — Maintenance

The point of this repo is that the machine stays close to what is written down. That needs a routine.

## Weekly

```bash
topgrade            # brew, casks, npm, cargo, rustup, uv, App Store, macOS
```

`topgrade` walks every package manager it detects. Config lives at `~/.config/topgrade.toml`;
disable steps you do not want:

```toml
[misc]
disable = ["containers", "system"]   # skip docker image pulls and macOS updates
cleanup = true
assume_yes = true
```

Manual equivalent, if you prefer to see each step:

```bash
brew update && brew upgrade && brew upgrade --cask
rustup update
uv tool upgrade --all
```

## Monthly

```bash
scripts/doctor.sh          # verify links, tools, git identity, fonts
brew autoremove            # drop orphaned dependencies
brew cleanup --prune=all   # delete old downloads and versions
brew doctor
```

`brew cleanup` reclaims real space — a year-old cache is routinely 5–15 GB.

## Catching drift

This is the step that prevents the cruft this repo was built to avoid.

```bash
scripts/packages.sh         # reports anything installed but not in a Brewfile
```

Or by hand:

```bash
brew leaves > /tmp/installed
brew list --cask >> /tmp/installed
```

Then, for each undeclared entry, make a decision:

| Situation | Action |
|---|---|
| you use it | add it to the right Brewfile, commit |
| you tried it once | `brew uninstall <name>` |
| you don't recognise it | `brew uses --installed <name>` — if nothing needs it, remove it |

**Never let "I'll sort it later" accumulate.** Deciding on one package a month is trivial; deciding
on forty after two years is why people wipe and reinstall.

## Capturing a change

Made a change by hand? Put it back in the repo the same day:

```bash
# packages
brew bundle dump --describe --force --file=/tmp/Brewfile.current
diff <(sort Brewfile) <(sort /tmp/Brewfile.current)

# VS Code extensions
code --list-extensions > dotfiles/vscode/extensions.txt

# dotfiles: already symlinked, so `git status` shows the change
git -C "$MACSTRAP_ROOT" status
```

Symlinking rather than copying is what makes this work: editing `~/.zshrc` *is* editing the repo.

## Disk

```bash
dust ~                                    # what is large
du -sh ~/Library/Caches/* | sort -h       # cache offenders
brew cleanup --prune=all
docker system prune -a                    # reclaims tens of GB; deletes unused images
rm -rf ~/Library/Developer/Xcode/DerivedData
```

`docker system prune -a` removes every image not backing a running container. Anything you cannot
re-pull is gone — check first if you build images locally.

## Migrating to a new Mac

Do **not** use Migration Assistant for the dev environment. It faithfully copies the cruft.

```bash
git clone https://github.com/<you>/macstrap.git ~/Dev/macstrap
cd ~/Dev/macstrap && ./bootstrap.sh
```

Then move by hand, deliberately: SSH keys (or generate new ones — better), `~/.zshrc.local` and
`~/.zshenv.local`, and password manager vaults. Everything else should come from this repo. If it
does not, that is a gap in the repo — fix it there.
