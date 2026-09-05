# 11 — Troubleshooting

Diagnose in order. Reproduce the fault. Isolate the layer. Then fix it. `scripts/doctor.sh` covers
most of the first two steps.

## `command not found` for something you just installed

| Cause | Test | Fix |
|---|---|---|
| shell has not re-read `PATH` | `which -a <cmd>` | `exec zsh` |
| Homebrew not on `PATH` | `echo $PATH \| tr : '\n' \| grep homebrew` | check `brew shellenv` is in `~/.zprofile` |
| something **assigned** `PATH` instead of appending | `zsh -c 'echo $PATH'` vs `echo $PATH` | find the offender, see below |

### The `PATH` assignment trap

An assignment such as `export PATH="/some/dirs"` in a startup file discards whatever the caller set
up. It destroys two things silently:

- the `node_modules/.bin` entry that `npm run`, `bun run` and `pnpm run` prepend for package scripts
- any inline `PATH="..." somecommand` prefix

Symptom: `bun run lint` fails with `eslint: command not found` while `eslint` works when typed by
hand. Fix it in the startup file. Append missing directories, never assign:

```zsh
case ":$PATH:" in *":$dir:"*) ;; *) export PATH="$dir:$PATH" ;; esac
```

Check these files in the order they run: `~/.zshenv`, `~/.zprofile`, `~/.zshrc`. For non-interactive
bash, also check whatever `BASH_ENV` points at. A directory missing from the outer shell's `PATH`
stays unreachable no matter what a later file says.

## Slow shell startup

```bash
time zsh -i -c exit                    # baseline; over ~0.5s is worth chasing
zsh -xv -i -c exit 2>&1 | tail -100    # what ran last before the prompt
```

Usual suspects, worst first:

| Cause | Cost | Fix |
|---|---|---|
| `nvm` sourced at startup | ~200ms | lazy-load it, or remove it (see `docs/05-languages.md`) |
| `conda init` block | ~150ms | remove it. Use `uv` instead |
| `compinit` with a stale dump | varies | `rm -f ~/.zcompdump && exec zsh` |
| tool init that shells out | 50ms each | prefer `eval "$(tool init zsh)"` over sourcing a generated script |

Bisect by commenting out halves of `.zshrc`.

## Completion is broken

| Symptom | Fix |
|---|---|
| Tab does nothing after installing a formula | `rm -f ~/.zcompdump ~/.zcompcache/* && exec zsh` |
| Tab matches nothing for `~/dev` when the folder is `~/Dev` | the `matcher-list` `zstyle` is missing or ran before `compinit` |
| garbled redraws, duplicated prompt | `zsh-syntax-highlighting` is not sourced **last** |
| `compinit: insecure directories` | `chmod -R go-w "$(brew --prefix)/share"` |

## Terminal rendering

| Symptom | Cause | Fix |
|---|---|---|
| boxes or blanks where icons should be | no Nerd Font, or the config names one that is not installed | `brew install --cask font-jetbrains-mono-nerd-font`, then restart the terminal |
| a config change has no effect | the key is declared twice. Ghostty applies the last one | `grep -n '^<key>' ~/.config/ghostty/config` |
| Ghostty reports `invalid value` on launch | a trailing `# comment` is part of the value | move the comment to its own line above the setting |
| garbled TUIs over SSH | the remote host lacks `xterm-ghostty` terminfo | `ghostty-terminfo user@host`, or use `ssh-dumb` |
| colours washed out | the theme has low-contrast pairs | raise `minimum-contrast` |

## Homebrew

| Symptom | Fix |
|---|---|
| `Error: Cannot install ... already installed` | `brew link --overwrite <formula>` |
| cask "is already an App at /Applications/..." | the app was installed by hand first. `brew install --cask --adopt <name>` takes ownership in place, without redownloading |
| `Refusing to load formula ... from untrusted tap` | see "Tap trust" below |
| `brew doctor` warns about unlinked kegs | usually harmless. Read before acting |
| formula fails to build from source | run `brew update` first. A stale tap has no bottle for your macOS version |
| everything is slow | `brew cleanup --prune=all` |

## Tap trust

Homebrew will not load a formula from a third-party tap until you trust it:

```
Error: Refusing to load formula oven-sh/bun/bun from untrusted tap oven-sh/bun.
```

`brew bundle` inherits the refusal, so on a fresh machine every tapped entry in a Brewfile fails.
There is no Brewfile syntax for this, on purpose. Trusting a tap means agreeing to run its
maintainers' Ruby, which should be a deliberate act. `scripts/packages.sh` asks once per tap.

```bash
brew trust --formula yoanbernabeu/tap/grepai   # narrow: this one package
brew trust --tap oven-sh/bun                   # broad: everything in the tap, now and future
```

Trust state lives in `~/.homebrew/trust.json` (or `$XDG_CONFIG_HOME/homebrew/` if that is set).
There is no `brew trust --list`; read the file.

**The trap:** `brew leaves` omits an untrusted tap's packages entirely. They are installed and on
your `PATH`, but the drift report cannot see them. The report then reads clean while the machine is
not. Check the trust file first whenever `scripts/packages.sh` says "no undeclared packages" and you
do not believe it.

## npm globals shadow Homebrew formulae

`npm install -g pnpm` writes `pnpm` into `$(brew --prefix)/lib/node_modules` and links it into
`bin/`. That is the same `bin/` the Homebrew formula wants. You get:

```
Error: Could not symlink bin/pn — target already exists
```

The cleanup is worse. **`npm uninstall -g pnpm` removes those `bin/` symlinks whether or not npm
created them.** Removing the npm copy takes the Homebrew formula's links with it, leaving
`pnpm: command not found` with the formula still installed. Recover with:

```bash
brew unlink pnpm && brew link pnpm
```

Pick one installer per tool. Macstrap makes the Homebrew `pnpm` formula the sole owner of `pnpm` and
`pnpx`. Homebrew declares that formula mutually conflicting with `corepack`, so run
`brew uninstall corepack` before re-running the packages step. Never install either owner with
`npm install -g`. npm globals share Homebrew's `bin` and recreate the same collision. See
[docs/05](05-languages.md) for the choice between the two owners.

## Docker

`docker: command not found` after installing Docker Desktop → open the app once. It installs the CLI
symlinks on first launch.

`brew list --cask` shows both `docker` and `docker-desktop` → that is one install, not two. Homebrew
renamed the cask and keeps a Caskroom symlink under the old token forever. Only `docker-desktop` is
real, and `brew install docker` resolves to it.

Two `docker` binaries on `PATH`, shown by `which -a docker` → you have both the formula and a cask.
Remove one. See `docs/05-languages.md`.

## Symlinks

```bash
scripts/doctor.sh                 # reports every link that is not pointing at the repo
ls -la ~/.zshrc                   # inspect one
readlink ~/.config/ghostty/config
```

Broken after moving the repo → the symlinks hold absolute paths. Re-run:

```bash
./bootstrap.sh --only dotfiles
```

Existing files move to `<name>.bak-<timestamp>`. Nothing is removed, so nothing is lost.

## When a script fails

```bash
./bootstrap.sh --only <step> --dry-run    # see the exact commands
bash -x scripts/<step>.sh                 # trace execution
```

Every step is idempotent. Re-running after a fix is safe.

## macOS BSD vs GNU

The tools here are BSD, not GNU, and the flags differ. This bites any script written on Linux:

| Tool | Difference |
|---|---|
| `date` | no `%N`. `-d` is not date-math; use `-v-1d` |
| `sed` | `-i` requires an argument: `sed -i '' 's/a/b/'` |
| `rsync` | macOS 15+ ships `openrsync`, which drops some GNU flags |
| `readlink` | no `-f` |
| `stat` | a different format string entirely |

Install the GNU versions when you need them: `brew install coreutils gnu-sed`. They arrive prefixed
with `g`, as `gdate` and `gsed`, unless you put the `gnubin` directory on `PATH`.
