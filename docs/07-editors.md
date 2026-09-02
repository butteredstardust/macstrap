# 07 — Editors

## VS Code

| Path | Managed as |
|---|---|
| `~/Library/Application Support/Code/User/settings.json` | **merged** from `dotfiles/vscode/settings.json` |
| extension list | `dotfiles/vscode/extensions.txt` |

### Why settings.json is merged and not symlinked

Every other dotfile here is a symlink, on the principle that editing the live file *is* editing the
repo. `settings.json` is the one exception, because VS Code writes to it — extensions persist their
own state there through the settings UI, and some of that state is secret. Auth tokens and internal
service URLs land in this file routinely, written by an extension rather than by hand, and you will
not notice. A symlink would commit whatever an extension last saved, the next time it saved it.

So `scripts/editors.sh` merges: the repo's keys win for the keys the repo declares, and anything else
already in the file is left alone. Same rule as `~/.gitconfig`, for the same reason.

The consequence to know about: **your local additions are never captured automatically.** If you
change a setting in the UI and want it tracked, add it to `dotfiles/vscode/settings.json` yourself.

```bash
scripts/editors.sh                                    # apply settings + extensions
code --list-extensions > dotfiles/vscode/extensions.txt   # capture current state
```

If `code` is not on `PATH`: open VS Code → `⇧⌘P` → **Shell Command: Install 'code' command in PATH**.

### What the settings do

| Group | Effect |
|---|---|
| Privacy | telemetry off, release notes off, recommendation prompts off |
| Appearance | Tokyo Night, Nerd Font with ligatures, no minimap, sticky scroll on |
| Editing | format on save, autosave on focus change, trim trailing whitespace |
| Friction | delete/drag confirmations off |

**The friction group only turns off prompts you can undo.** Deleting a file you can restore from git
is worth one less dialog; executing untrusted code is not.

Workspace Trust is therefore left **on**. Disabling it (`security.workspace.trust.enabled: false`)
means opening a cloned repo runs its tasks and extension code without asking — defensible on a
machine where you only ever clone your own work, indefensible as a default someone else inherits by
running this repo. If you want it, set it in your own user settings; the merge in `scripts/editors.sh`
will leave it alone. The same goes for `security.promptForLocalFileProtocolHandling`.

### Settings that must not live here

`dotfiles/vscode/settings.json` is public. Anything with a token, an internal hostname, or a URL to
a private service belongs in the project's `.vscode/settings.json` — or in nothing at all. Check
before you copy a key here: the settings UI writes credentials into the same file as your font
choice, and the file gives you no hint which is which.

### Extensions

Kept short, and the rule is "one extension per job" rather than "as few as possible".

The distinction that matters is **inline-completion providers versus agents you invoke**. Copilot,
Gemini Code Assist, Continue and friends all register a provider for the same ghost-text slot; with
two or more installed they race, flicker, and you cannot tell which one produced a suggestion. Pick
one. Agent extensions you summon deliberately — Claude Code, Kilo, opencode — do not compete for that
slot and several can coexist. Three is fine. The fourth is how it starts going wrong.

The same rule catches non-AI duplicates: two Docker extensions means two container panels and two
sets of palette commands. `docker.docker` supersedes `ms-azuretools.vscode-docker`; keep the former.

Also skipped: language packs whose language server duplicates one already bundled (installing both
`vtsls` and the built-in TypeScript server means two servers indexing the same project).

## One editor

There is deliberately no second GUI editor here. A second editor is only worth its config, its
extension set and its keymap divergence if you actually reach for it, and "fast editor for big
files" is a job `bat`, `rg` and `less` already do from a terminal that is already open.

If you do want one, add the cask and a `dotfiles/<editor>/` directory; the symlink helper in
`scripts/lib.sh` does not care which editor it is.

## CLI agents

Claude Code installs via its own script, not Homebrew, because it self-updates:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

It lands in `~/.local/bin`, which `.zshrc` puts on `PATH`.

Per-project instructions go in the project's `CLAUDE.md`. Machine-wide preferences go in
`~/.claude/`, which is **not** tracked here — it accumulates history, tokens and session state.
`~/.claude/settings.local.json` is in the global gitignore for the same reason.
