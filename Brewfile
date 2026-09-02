# macstrap — core bundle
#
# Everything here is used daily and is safe on any Mac. Install with:
#   brew bundle --file=Brewfile
#
# Rules for this file:
#   - Only direct dependencies. Never pin a transitive one (an `icu4c@75` line
#     in a Brewfile means something leaked out of `brew leaves`, not that you
#     wanted it).
#   - One tool per job. If two entries solve the same problem, delete one.

# --- Taps -----------------------------------------------------------------
tap "oven-sh/bun"
tap "anomalyco/tap"

# --- Shell ----------------------------------------------------------------
brew "zsh-autosuggestions"       # ghost-text completion from history
brew "zsh-completions"           # extra completion definitions
brew "zsh-syntax-highlighting"   # must be sourced LAST — see docs/03-shell.md
brew "starship"                  # prompt; config in dotfiles/starship
brew "bash"                      # macOS ships bash 3.2 (2007). Scripts want >= 4.

# --- Core CLI -------------------------------------------------------------
brew "git"
brew "git-delta"                 # syntax-highlighted diffs; wired up in gitconfig
brew "gh"                        # GitHub CLI: auth, PRs, releases
brew "jq"                        # JSON
brew "fd"                        # find, but sane defaults and gitignore-aware
brew "ripgrep"                   # grep, but fast and gitignore-aware
brew "bat"                       # cat with paging + highlighting
brew "eza"                       # ls with git status and a tree mode
brew "dust"                      # du, sorted and visual
brew "procs"                     # ps, readable
brew "htop"                      # top, interactive
brew "tree"
brew "watch"
brew "httpie"                    # curl for humans; keep curl for scripts

# --- Dev runtimes ---------------------------------------------------------
brew "node"                      # LTS-ish; see docs/05-languages.md for pinning
brew "pnpm"                      # NOT alongside corepack — they fight over the
                                 # same pnpm/pnpx binaries. See docs/05.
brew "oven-sh/bun/bun"
brew "python@3.12"              # a system-wide interpreter for one-off scripts.
                                 # Project versions come from uv, not from here,
                                 # so this only needs to be *a* modern Python —
                                 # not the newest. 3.12 has the widest wheel
                                 # coverage of the versions still supported.
brew "uv"                        # Python envs + tool installs; replaces pipx
brew "rustup"                    # NOT `rust` — rustup manages toolchains.
                                 # Keg-only: needs $(brew --prefix)/opt/rustup/bin
                                 # on PATH, and `rustup default stable` after.
                                 # .zshenv and scripts/languages.sh handle both.

# --- AI coding agents -----------------------------------------------------
# Terminal agents, used daily. These coexist fine: each is a separate binary
# you invoke deliberately, unlike editor extensions, which fight over the same
# inline-completion slot (see docs/07-editors.md).
#
# Claude Code is deliberately absent — it ships its own self-updating installer
# rather than a formula. scripts/editors.sh handles it.
brew "anomalyco/tap/opencode"
cask "codex"                     # OpenAI Codex CLI; ships as a cask, not a formula

# --- Maintenance ----------------------------------------------------------
brew "topgrade"                  # one command to update everything
brew "mas"                       # Mac App Store CLI, for `brew bundle dump`
brew "shellcheck"                # required by scripts/test.sh
