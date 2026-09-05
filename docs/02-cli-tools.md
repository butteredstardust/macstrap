# 02 — CLI tools

## Modern replacements

Each tool below replaces a BSD coreutil that is slower, less readable, or both. `dotfiles/zsh/zshrc`
sets the aliases. Each alias is guarded by `command -v`, so the shell still works when a tool is
missing.

| Replaces | Tool | Why |
|---|---|---|
| `ls` | `eza` | git status per file, `--tree` mode, icons, sane colours |
| `cat` | `bat` | syntax highlighting, line numbers, paging |
| `find` | `fd` | respects `.gitignore`, regex by default, ~5× faster |
| `grep` | `ripgrep` (`rg`) | respects `.gitignore`, parallel, the fastest of its class |
| `du` | `dust` | sorted, visual, no `-sh *` incantation |
| `ps` | `procs` | readable columns, tree view, port info |
| `top` | `htop` | interactive, sortable |
| `diff` | `git-delta` | side-by-side, syntax-highlighted; wired into git as pager |
| `curl` (interactive) | `httpie` | sane defaults for exploring APIs. Keep `curl` for scripts |

**Aliasing caveat:** `bat` is not a drop-in replacement for `cat` in scripts. Keep the aliases in
`.zshrc`, never in `.zshenv`. Non-interactive shells do not expand aliases, so scripts keep getting
the real `cat`.

## Kept as-is

| Tool | Why not replaced |
|---|---|
| `git` | the Homebrew build, not Apple's |
| `jq` | still the JSON tool; nothing has displaced it |
| `curl` | ubiquitous, scriptable, already installed |
| `ssh` | Apple's build integrates with Keychain and the Secure Enclave |

## Not installed, on purpose

| Tool | Verdict |
|---|---|
| `ack` | superseded by `ripgrep` in every dimension. Kept in `Brewfile.optional` for muscle memory |
| `nvm` | costs ~200ms per shell to source. Homebrew's node covers the common case. In `Brewfile.optional` |
| `pipx` | `uv tool install` does the same job, faster, with a tool you already have |
| `pyenv` | `uv python install` manages interpreters |
| `oh-my-zsh` | a framework for three plugins you can source in three lines. See `docs/03-shell.md` |

## GitHub CLI

```bash
gh auth login          # browser flow; stores the token in the Keychain
gh auth status
```

`gh` also configures git's credential helper. HTTPS pushes then stop asking for a password.

## Verify

```bash
scripts/doctor.sh
```
