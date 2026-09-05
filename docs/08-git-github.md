# 08 — Git & GitHub

## Identity

`scripts/dotfiles.sh` renders `~/.gitconfig` from `dotfiles/git/gitconfig.template`. It is a copy,
not a symlink, because it holds your name and email and this repo is public.

```bash
GIT_NAME='your-handle' \
GIT_EMAIL='1234567+your-handle@users.noreply.github.com' \
scripts/dotfiles.sh
```

**Use the GitHub noreply address.** Every commit you push publishes its author email permanently, in
a scrapable API. Find yours at <https://github.com/settings/emails>. The form is
`<numeric-id>+<username>@users.noreply.github.com`. Tick "Keep my email address private" there too,
so the web UI does not undo it.

Already leaked a real address? `git-filter-repo` rewrites history. Every existing clone, fork and
cached API response still keeps the old value, so treat that address as public from then on.

## Config worth explaining

| Setting | Effect |
|---|---|
| `push.autoSetupRemote = true` | `git push` on a new branch works without `-u origin <name>` |
| `pull.ff = only` | a diverged pull fails loudly instead of creating a surprise merge commit |
| `fetch.prune = true` | local refs for deleted remote branches disappear |
| `merge.conflictstyle = zdiff3` | shows the common ancestor in conflicts. Far easier to resolve |
| `diff.algorithm = histogram` | better hunk matching than the default Myers on refactors |
| `rebase.autostash = true` | rebase with a dirty working tree. Stash and restore happen automatically |
| `rerere.enabled = true` | remembers conflict resolutions and replays them on the next rebase |
| `branch.sort = -committerdate` | `git branch` lists most recent first |
| `core.pager = delta` | syntax-highlighted diffs. `n` and `N` move between files |

## Global ignore

`~/.config/git/ignore` holds what is never worth committing in *any* repo: `.DS_Store`, editor
scratch files, `**/.claude/settings.local.json`.

**Keep it narrow.** A global rule hides a file from you but not from collaborators. That produces
"it works on my machine" bugs, where a needed file never gets staged.

## SSH keys

```bash
ssh-keygen -t ed25519 -C "macstrap $(date +%Y-%m)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(scutil --get ComputerName)"
```

`~/.ssh/config` to make the Keychain integration stick across reboots:

```
Host *
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
```

Choose ed25519 over RSA: shorter, faster, and no key-size decision to get wrong. `-C` sets a comment,
not an email. Put no address in it.

**Never commit `~/.ssh`.** Not to a private repo either. Generate a separate key per machine and add
each to GitHub. Revoking one machine is then one click. Moving key material between machines needs an
encrypted channel and a deliberate decision.

## Commit signing

Optional. It is the reason `~/.gitconfig.local` exists. SSH signing is the low-friction option:

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing
```

## GitHub CLI

```bash
gh auth login       # browser flow; token goes to the Keychain
gh auth status
gh repo create macstrap --public --source=. --push
```

`gh` sets itself up as git's credential helper. HTTPS pushes then stop prompting.
`~/.config/gh/hosts.yml` holds that token. This repo does not track it, and never should.
