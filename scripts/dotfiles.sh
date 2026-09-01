#!/usr/bin/env bash
# Symlink dotfiles into place, and render the git identity from its template.
#
# Existing files are moved to <name>.bak-<timestamp>, never deleted.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Dotfiles"

# Guards repeated here, not just in preflight: this script is executable on its
# own and via `--only`, and writing $HOME dotfiles as root would create files
# the real user cannot edit afterwards.
require_macos
refuse_root

# --- Shell ----------------------------------------------------------------
link dotfiles/zsh/zshrc   "$HOME/.zshrc"
link dotfiles/zsh/zshenv  "$HOME/.zshenv"
link dotfiles/zsh/zprofile "$HOME/.zprofile"

# Create the local override files so they exist to be edited, and so a missing
# file never turns into a confusing "why is my secret not set".
for local_file in .zshrc.local .zshenv.local; do
  if [ ! -e "$HOME/$local_file" ]; then
    run touch "$HOME/$local_file"
    ok "created empty $HOME/$local_file (machine-local, never committed)"
  fi
done

# --- Terminal & prompt ----------------------------------------------------
link dotfiles/ghostty/config      "$HOME/.config/ghostty/config"
link dotfiles/starship/starship.toml "$HOME/.config/starship.toml"

# --- Git ------------------------------------------------------------------
link dotfiles/git/ignore "$HOME/.config/git/ignore"

# ~/.gitconfig is COPIED, not linked: it carries your name and email, and this
# repo is public. Regenerate it by deleting ~/.gitconfig and re-running.
if [ -f "$HOME/.gitconfig" ] && grep -q '__GIT_NAME__' "$HOME/.gitconfig" 2>/dev/null; then
  # shellcheck disable=SC2088  # display text, not a path to be expanded
  warn "~/.gitconfig still contains template placeholders; regenerating"
  backup "$HOME/.gitconfig"
fi

if [ ! -f "$HOME/.gitconfig" ]; then
  git_name="${GIT_NAME:-}"
  git_email="${GIT_EMAIL:-}"

  if [ -z "$git_name" ] && [ -t 0 ] && [ "$DRY_RUN" != "1" ]; then
    printf '  ?? git user.name: '; read -r git_name
  fi
  if [ -z "$git_email" ] && [ -t 0 ] && [ "$DRY_RUN" != "1" ]; then
    printf '  ?? git user.email (use your GitHub noreply address): '; read -r git_email
  fi

  if [ -z "$git_name" ] || [ -z "$git_email" ]; then
    warn "git identity not set; skipping ~/.gitconfig"
    warn "re-run with: GIT_NAME='you' GIT_EMAIL='id+user@users.noreply.github.com' scripts/dotfiles.sh"
  elif [ "$DRY_RUN" = "1" ]; then
    skip "would render ~/.gitconfig from template"
  else
    # Copy the template with the placeholders stripped, then let git itself
    # write the identity. Interpolating the values into a sed replacement would
    # break on the characters a real name legitimately contains: `&` expands to
    # the whole match, and `\` and the `|` delimiter corrupt the expression.
    # -E, not BRE: BSD grep has no `\|` alternation, same trap as BSD sed.
    grep -vE '__GIT_NAME__|__GIT_EMAIL__' \
      "$MACSTRAP_ROOT/dotfiles/git/gitconfig.template" > "$HOME/.gitconfig"
    git config --file "$HOME/.gitconfig" user.name  "$git_name"
    git config --file "$HOME/.gitconfig" user.email "$git_email"
    ok "wrote ~/.gitconfig for $git_name <$git_email>"
  fi
else
  # shellcheck disable=SC2088  # display text, not a path to be expanded
  skip "~/.gitconfig exists (delete it to regenerate from the template)"
fi

# --- Default shell --------------------------------------------------------
# macOS has defaulted to zsh since Catalina, but a migrated account can still
# be on bash.
if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
  warn "login shell is $SHELL, not zsh"
  confirm "change it to /bin/zsh?" && run chsh -s /bin/zsh
fi

ok "Dotfiles complete — run 'exec zsh' or open a new terminal"
