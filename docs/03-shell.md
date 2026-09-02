# 03 — Shell

No framework. Three Homebrew plugins, sourced directly, in a specific order.

## Which file runs when

This is the single most common source of "why is my variable not set".

| File | Login | Interactive | Script / `zsh -c` | Put here |
|---|:--:|:--:|:--:|---|
| `.zshenv` | ✅ | ✅ | ✅ | env a *non-interactive* tool needs. Keep it tiny |
| `.zprofile` | ✅ | — | — | `brew shellenv`, one-time login setup |
| `.zshrc` | ✅ | ✅ | — | aliases, prompt, completion, keybindings |
| `.zlogin` | ✅ | — | — | rarely needed |

Build tooling shells out with `zsh -c`, which **skips `.zshrc` entirely**. A signing key or API
token exported only there is invisible to it — that is why `.zshenv` exists in this setup.

Everything slow belongs in `.zshrc`. Everything in `.zshenv` runs for every subshell of every
script, so a single expensive command there multiplies across a build.

## Load order in `.zshrc`

Order is load-bearing. The file is written in this sequence and moving a block breaks it:

1. `PATH` additions (idempotent — see below)
2. environment, history options
3. `starship init`
4. `zle -N` widget definitions and `bindkey`
5. `FPATH` from brew, then **`compinit`**
6. `zstyle` completion rules — *must* come after `compinit`
7. `zmodload zsh/complist`
8. `zsh-autosuggestions`, then **`zsh-syntax-highlighting` last**

`zsh-syntax-highlighting` wraps every ZLE widget that exists when it loads. Anything sourced after
it is unhighlighted, and anything that redefines a widget it already wrapped produces garbled
redraws. Its README says "last"; it means it.

## PATH without duplicates

```zsh
path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) [ -d "$1" ] && export PATH="$1:$PATH" ;;
  esac
}
```

Blind `export PATH="X:$PATH"` stacks a new copy every time the file is sourced — and terminals
re-exec the shell more often than you would think. The `-d` guard also stops non-existent
directories accumulating after you uninstall something.

**A hard `export PATH=...` (assignment, not append) anywhere in shell startup is a bug.** It
discards whatever the caller set up — including the `node_modules/.bin` entry `npm run`/`bun run`
prepend for package scripts, and any inline `PATH="..." cmd` prefix. The symptom is a package script
failing with `eslint: command not found` while `eslint` works fine when typed by hand.

### Which file a `PATH` entry belongs in

`.zshrc` is the default, because most `PATH` entries only matter to a human typing commands. But a
directory holding a **compiler or build tool** goes in `.zshenv` instead. Build tooling shells out
with `zsh -c`, which reads `.zshenv` and skips `.zshrc` entirely, so a toolchain configured in
`.zshrc` works when you type it and disappears under anything that automates it. Rust is the case
here — see [docs/05](05-languages.md).

### Prepend or append

Prepending means "this wins over the system copy", and that is a claim worth making deliberately.
Where a directory may hold a *stale duplicate* of something another manager owns, append instead.
`~/.cargo/bin` is the example: `cargo install` writes there, so it must stay reachable, but the
upstream rustup installer also leaves shims there and its own `~/.cargo/env` prepends the directory
— which silently outranks the Homebrew-managed toolchain. Appended, a leftover shim is harmless.

## Completion

```zsh
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
```

The macOS filesystem is case-insensitive, so `cd ~/dev` works and you type lowercase out of habit —
but zsh completion is case-sensitive by default, so Tab there matches nothing and looks broken. The
rule tries exact first, then lower→upper, then partial-word (`~/D/pr` → `~/Dev/project`).

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

Up/Down are bound to `history-beginning-search-*-end`: they search history for what you have
already typed, instead of walking every command blindly.

## Ghostty over SSH

Ghostty sets `TERM=xterm-ghostty`, which almost no remote host has a terminfo entry for. Without it
the remote side falls back to something crippled: garbled redraws, dead arrow keys, broken TUIs.

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

Anything with a token, a hostname, an internal URL, or an absolute path unique to one machine goes
in these. Nothing in this repo should ever need editing to make it work on a second machine.
