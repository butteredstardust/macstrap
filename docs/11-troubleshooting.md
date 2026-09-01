# 11 — Troubleshooting

Diagnose in order: reproduce, isolate the layer, then fix. `scripts/doctor.sh` covers most of the
first two steps.

## `command not found` for something you just installed

| Cause | Test | Fix |
|---|---|---|
| shell has not re-read `PATH` | `which -a <cmd>` | `exec zsh` |
| Homebrew not on `PATH` | `echo $PATH \| tr : '\n' \| grep homebrew` | check `brew shellenv` is in `~/.zprofile` |
| something **assigned** `PATH` instead of appending | `zsh -c 'echo $PATH'` vs `echo $PATH` | find the offender, see below |

### The `PATH` assignment trap

A hard `export PATH="/some/dirs"` (assignment, not append) in a startup file discards whatever the
caller set up. Two things it silently destroys:

- the `node_modules/.bin` entry that `npm run` / `bun run` / `pnpm run` prepend for package scripts
- any inline `PATH="..." somecommand` prefix

Symptom: `bun run lint` fails with `eslint: command not found` while `eslint` works when typed by
hand. The fix is always in the startup file — append missing directories, never assign:

```zsh
case ":$PATH:" in *":$dir:"*) ;; *) export PATH="$dir:$PATH" ;; esac
```

Files to check, in the order they run: `~/.zshenv`, `~/.zprofile`, `~/.zshrc`, and — for
non-interactive bash specifically — whatever `BASH_ENV` points at. A directory missing from the
outer shell's `PATH` is unreachable no matter what a later file says.

## Slow shell startup

```bash
time zsh -i -c exit                    # baseline; over ~0.5s is worth chasing
zsh -xv -i -c exit 2>&1 | tail -100    # what ran last before the prompt
```

Usual suspects, worst first:

| Cause | Cost | Fix |
|---|---|---|
| `nvm` sourced at startup | ~200ms | lazy-load it, or drop it (see `docs/05-languages.md`) |
| `conda init` block | ~150ms | remove it; use `uv` instead |
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
| boxes/blanks where icons should be | no Nerd Font, or the config names one that is not installed | `brew install --cask font-jetbrains-mono-nerd-font`, restart the terminal |
| a config change has no effect | the key is declared twice; Ghostty applies the last one | `grep -n '^<key>' ~/.config/ghostty/config` |
| garbled TUIs over SSH | remote host lacks `xterm-ghostty` terminfo | `ghostty-terminfo user@host`, or use `ssh-dumb` |
| colours washed out | theme has low-contrast pairs | raise `minimum-contrast` |

## Homebrew

| Symptom | Fix |
|---|---|
| `Error: Cannot install ... already installed` | `brew link --overwrite <formula>` |
| cask "is already an App at /Applications/..." | app was installed manually first: `brew install --cask --force <name>` to adopt it |
| `brew doctor` warns about unlinked kegs | usually harmless; read before acting |
| formula fails to build from source | `brew update` first — a stale tap has no bottle for your macOS version |
| everything is slow | `brew cleanup --prune=all` |

## Docker

`docker: command not found` after installing Docker Desktop → open the app once; it installs the CLI
symlinks on first launch.

Two `docker` binaries on `PATH` (`which -a docker` shows more than one) → you have both the formula
and a cask. Remove one; see `docs/05-languages.md`.

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

Existing files are backed up to `<name>.bak-<timestamp>`, never deleted, so nothing is lost.

## When a script fails

```bash
./bootstrap.sh --only <step> --dry-run    # see the exact commands
bash -x scripts/<step>.sh                 # trace execution
```

Every step is idempotent — re-running after a fix is safe.

## macOS BSD vs GNU

The tools here are BSD, not GNU, and the flags differ. This bites in any script written on Linux:

| Tool | Difference |
|---|---|
| `date` | no `%N`; `-d` is not date-math (`-v-1d` instead) |
| `sed` | `-i` requires an argument: `sed -i '' 's/a/b/'` |
| `rsync` | macOS 15+ ships `openrsync`; some GNU flags are unsupported |
| `readlink` | no `-f` |
| `stat` | different format string entirely |

Install GNU versions if you need them (`brew install coreutils gnu-sed`); they arrive prefixed with
`g` (`gdate`, `gsed`) unless you put the `gnubin` directory on `PATH`.
