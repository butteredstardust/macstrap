# 02 — CLI tools

## Modern replacements

Each of these replaces a BSD coreutil that is slower, less readable, or both. The aliases are set in
`dotfiles/zsh/zshrc`, guarded by `command -v` so the shell still works if a tool is missing.

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

**Aliasing caveat:** `alias cat='bat --paging=never'` is fine interactively, but `bat` is not a
drop-in for scripts. Aliases are not expanded in non-interactive shells, so scripts still get the
real `cat` — this is why the aliases live in `.zshrc` and not `.zshenv`.

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
| `ack` | superseded by `ripgrep` in every dimension. In `Brewfile.optional` for muscle memory only |
| `nvm` | slow to source (~200ms per shell) and unnecessary when brew's node plus per-project `corepack` cover it. Optional |
| `pipx` | `uv tool install` does the same thing, faster, and you already have `uv` |
| `pyenv` | `uv python install` manages interpreters now |
| `oh-my-zsh` | a framework to configure three plugins you can source in three lines. See `docs/03-shell.md` |

## GitHub CLI

```bash
gh auth login          # browser flow; stores the token in the Keychain
gh auth status
```

`gh` also configures git's credential helper, which is why HTTPS pushes stop asking for a password.

## Verify

```bash
scripts/doctor.sh
```
