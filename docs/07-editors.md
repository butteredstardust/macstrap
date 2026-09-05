# 07 — Editors

## VS Code

| Path | Managed as |
|---|---|
| `~/Library/Application Support/Code/User/settings.json` | **merged** from `dotfiles/vscode/settings.json` |
| extension list | `dotfiles/vscode/extensions.txt` |

### Why settings.json is merged and not symlinked

Every other dotfile here is a symlink, so editing the live file *is* editing the repo.
`settings.json` is the one exception, because VS Code writes to it. Extensions persist their own
state there through the settings UI, and some of that state is secret. Auth tokens and internal
service URLs land in this file routinely, written by an extension rather than by hand. A symlink
would publish whatever an extension last saved.

So `scripts/editors.sh` merges instead. The repo's keys win for the keys the repo declares.
Everything else already in the file stays untouched. Same rule as `~/.gitconfig`, for the same
reason.

Know the consequence: **the merge never captures your local additions.** Change a setting in the UI
and want it tracked? Add it to `dotfiles/vscode/settings.json` yourself.

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

**The friction group only turns off prompts you can undo.** Losing one dialog is worth it for
deleting a file you can restore from git. It is not worth it for executing untrusted code.

Workspace Trust therefore stays **on**. Setting `security.workspace.trust.enabled: false` makes
opening a cloned repo run its tasks and extension code without asking. That is defensible on a
machine where you only clone your own work. It is indefensible as a default someone inherits by
running this repo. Set it in your own user settings if you want it. The merge in
`scripts/editors.sh` leaves it alone, as it does
`security.promptForLocalFileProtocolHandling`.

### Settings that must not live here

`dotfiles/vscode/settings.json` is public. Keep anything with a token, an internal hostname or a
private service URL out of it. Put those in the project's `.vscode/settings.json`, or nowhere. Check
every key before copying it here. The settings UI writes credentials into the same file as your font
choice, and gives you no hint which is which.

### Extensions

The rule is one extension per job, not as few as possible.

The distinction that matters: **inline-completion providers versus agents you invoke.** Copilot,
Gemini Code Assist and Continue each register a provider for the same ghost-text slot. Install two
and they race, flicker, and give no way to tell which one produced a suggestion. Pick one.

Agent extensions you summon deliberately — Claude Code, Kilo, opencode — never compete for that slot.
Several coexist. Three is fine.

The same rule catches non-AI duplicates. Two Docker extensions mean two container panels and two sets
of palette commands. `docker.docker` supersedes `ms-azuretools.vscode-docker`, so keep
`docker.docker`.

Skip language packs whose language server duplicates a bundled one. Installing `vtsls` alongside the
built-in TypeScript server puts two servers on the same project.

## One editor

There is deliberately no second GUI editor here. A second editor costs its own config, extension set
and keymap divergence. It only pays that back if you reach for it. `bat`, `rg` and `less` already
handle big files, from a terminal that is already open.

Want one anyway? Add the cask and a `dotfiles/<editor>/` directory. The symlink helper in
`scripts/lib.sh` works for any editor.

## CLI agents

Claude Code installs through its own script, not Homebrew, because it self-updates:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

It lands in `~/.local/bin`, which `.zshrc` puts on `PATH`.

Put per-project instructions in the project's `CLAUDE.md`. Put machine-wide preferences in
`~/.claude/`. This repo does **not** track `~/.claude/`: it accumulates history, tokens and session
state. The global gitignore covers `~/.claude/settings.local.json` for the same reason.
