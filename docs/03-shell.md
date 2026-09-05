# 03 — Shell

No framework. Three Homebrew plugins, sourced directly, in a specific order.

## Which file runs when

Read this table before adding anything to a startup file. It answers the most common shell question:
"why is my variable not set?"

| File | Login | Interactive | Script / `zsh -c` | Put here |
|---|:--:|:--:|:--:|---|
| `.zshenv` | ✅ | ✅ | ✅ | env a *non-interactive* tool needs. Keep it tiny |
| `.zprofile` | ✅ | — | — | `brew shellenv`, one-time login setup |
| `.zshrc` | ✅ | ✅ | — | aliases, prompt, completion, keybindings |
| `.zlogin` | ✅ | — | — | rarely needed |

Build tooling shells out with `zsh -c`, which **skips `.zshrc` entirely**. A signing key or API
token exported only there stays invisible to it. Export it from `.zshenv` instead.

Keep everything slow in `.zshrc`. `.zshenv` runs for every subshell of every script, so one
expensive command there multiplies across a build.

## Load order in `.zshrc`

Order is load-bearing. Moving a block breaks the file. The sequence is:

1. `PATH` additions (idempotent — see below)
2. environment, history options
3. `starship init`
4. `zle -N` widget definitions and `bindkey`
5. `FPATH` from brew, then **`compinit`**
6. `zstyle` completion rules — *must* come after `compinit`
7. `zmodload zsh/complist`
8. `zsh-autosuggestions`, then **`zsh-syntax-highlighting` last**

`zsh-syntax-highlighting` wraps every ZLE widget that exists when it loads. Anything sourced after it
stays unhighlighted. Anything redefining a widget it already wrapped produces garbled redraws. Source
it last.

## PATH without duplicates

```zsh
path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) [ -d "$1" ] && export PATH="$1:$PATH" ;;
  esac
}
```

A blind `export PATH="X:$PATH"` stacks a new copy every time the file is sourced. Terminals re-exec
the shell often, so the copies add up. The `-d` guard also keeps removed directories from
accumulating.

**Never assign `PATH` in a startup file. Append to it.** An assignment discards whatever the caller
set up. It destroys the `node_modules/.bin` entry that `npm run` and `bun run` prepend for package
scripts. It also destroys any inline `PATH="..." cmd` prefix. The symptom: a package script fails
with `eslint: command not found` while `eslint` works when typed by hand.

### Which file a `PATH` entry belongs in

Default to `.zshrc`. Most `PATH` entries only matter to a human typing commands.

Move an entry to `.zshenv` only when **non-interactive zsh** needs it. That means an editor, build
script or other automation invokes the tool through `zsh -c`, which reads `.zshenv` and skips
`.zshrc`. Rust is the one case here. See [docs/05](05-languages.md).

### Prepend or append

Prepending claims "this wins over the system copy". Make that claim deliberately.

Append instead where a directory may hold a stale duplicate of something another manager owns.
`~/.cargo/bin` is that case. `cargo install` writes there, so it must stay reachable. The upstream
rustup installer also leaves shims there, and its `~/.cargo/env` prepends the directory ahead of the
Homebrew-managed toolchain.

Appending alone cannot repair a bad order inherited from a parent process. So `.zshenv` removes both
Rust entries, then rebuilds the order: Homebrew rustup first, `~/.cargo/bin` last.

## Completion

```zsh
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
```

The macOS filesystem is case-insensitive, so `cd ~/dev` works and lowercase becomes a habit. zsh
completion is case-sensitive by default, so Tab matches nothing there and looks broken. This rule
tries exact first, then lower→upper, then partial word (`~/D/pr` → `~/Dev/project`).

| Setting | Effect |
|---|---|
| `menu select` | second Tab opens an arrow-navigable menu |
| `use-cache on` | caches slow completers (brew, docker, kubectl) |
| `zmodload zsh/complist` | required by the arrow-key menu |

If completions stop updating after installing a formula: `rm -f ~/.zcompdump ~/.zcompcache/* && exec zsh`.

## History

| Option | Effect |
|---|---|
| `HIST_IGNORE_ALL_DUPS` | one entry per unique command |
| `SHARE_HISTORY` | panes see each other's commands immediately |
| `INC_APPEND_HISTORY` | written as you go, not on exit — survives a crash |
| `HIST_IGNORE_SPACE` | a leading space keeps a command out of history (use for secrets) |
| `HIST_VERIFY` | `!!` expands into the buffer for review instead of executing |

Up and Down are bound to `history-beginning-search-*-end`. They search history for what you have
already typed, instead of walking every command blindly.

## Ghostty over SSH

Ghostty sets `TERM=xterm-ghostty`. Almost no remote host ships that terminfo entry. Without it the
remote side falls back to a crippled terminal: garbled redraws, dead arrow keys, broken TUIs.

```bash
ghostty-terminfo user@host      # push the entry once per host
ssh-dumb user@host              # or connect as plain xterm-256color
```

Use `ssh-dumb` for hosts you cannot or should not write to — shared boxes, appliances, one-off jumps.

## Local overrides

| File | Sourced by | Tracked |
|---|---|---|
| `~/.zshrc.local` | `.zshrc`, last | ❌ |
| `~/.zshenv.local` | `.zshenv`, last | ❌ |
| `~/.zprofile.local` | `.zprofile`, last | ❌ |
| `~/.gitconfig.local` | `.gitconfig` `[include]` | ❌ |

Put anything with a token, a hostname, an internal URL or a machine-specific path in these files.
Nothing in this repo should need editing to work on a second machine.
