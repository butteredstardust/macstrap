# 07 — Editors

## VS Code

| Path | Managed as |
|---|---|
| `~/Library/Application Support/Code/User/settings.json` | symlink → `dotfiles/vscode/settings.json` |
| extension list | `dotfiles/vscode/extensions.txt` |

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
| Friction | delete/drag confirmations off, workspace trust off |

**The friction group is a deliberate trade.** Disabling workspace trust means opening a cloned repo
executes its tasks and extension code without asking. Reasonable on a personal machine where you
clone your own work; reconsider it on a work machine or if you review untrusted code.

### Settings that must not live here

`dotfiles/vscode/settings.json` is public. Anything with a token, an internal hostname, or a URL to
a private service belongs in the project's `.vscode/settings.json` — or in nothing at all. The
original of this file carried an auth token for a local proxy; that is exactly the leak this split
prevents.

### Extensions

Kept short. Notable omission: **multiple AI assistants**. Copilot, Claude Code, Continue, Kilo and
friends all register inline-completion providers; with two or more installed they race, flicker, and
you cannot tell which one produced a suggestion. Pick one.

Also skipped: language packs whose language server duplicates one already bundled (installing both
`vtsls` and the built-in TypeScript server means two servers indexing the same project).

## Zed

`~/.config/zed/settings.json` → `dotfiles/zed/settings.json`.

`"base_keymap": "VSCode"` so muscle memory carries between the two. Telemetry off. Zed's defaults
are good, so the file is short on purpose.

Where Zed wins: opening a multi-hundred-megabyte log, or a quick edit where VS Code's startup is the
slowest part of the task.

## CLI agents

Claude Code installs via its own script, not Homebrew, because it self-updates:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

It lands in `~/.local/bin`, which `.zshrc` puts on `PATH`.

Per-project instructions go in the project's `CLAUDE.md`. Machine-wide preferences go in
`~/.claude/`, which is **not** tracked here — it accumulates history, tokens and session state.
`~/.claude/settings.local.json` is in the global gitignore for the same reason.
