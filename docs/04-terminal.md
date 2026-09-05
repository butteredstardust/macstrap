# 04 — Terminal & fonts

## Ghostty

Native, GPU-accelerated, configured by a plain text file. `~/.config/ghostty/config` is a symlink to
`dotfiles/ghostty/config`.

| Key | Notes |
|---|---|
| `⇧⌘,` | reload config without restarting |
| `⌘,` | open the config file |
| `⌘D` / `⇧⌘D` | split right / down |
| `⌘T` | new tab |

```bash
ghostty +list-themes                  # browse bundled themes
ghostty +show-config --default --docs # every option, documented
ghostty +list-fonts
```

**Gotcha: Ghostty applies the _last_ occurrence of a duplicated key.** Declaring `window-padding-x`
twice discards the first value silently. That is how a config drifts into contradicting itself.
Declare each key exactly once.

**Gotcha: a trailing comment is part of the value.** Ghostty parses everything after `=` to the end
of the line, so `font-thicken = true   # comment` fails with `invalid value`. Put comments on their
own line above the setting.

### Settings worth knowing

| Setting | Why |
|---|---|
| `minimum-contrast = 1.3` | forces legibility on low-contrast theme pairs. `1.0` disables it |
| `macos-option-as-alt = left` | left ⌥ sends `Esc+` for readline word-motion. Right ⌥ still types `é`/`ø` |
| `font-thicken = true` | macOS only. Compensates for thin stem rendering |
| `keybind = shift+enter=text:\n` | inserts a newline instead of submitting. Required by REPLs and CLI agents |
| `background-opacity = 0.96` | below ~0.9 costs legibility for no real benefit |

### Theme choice

`theme = Gruvbox Dark`. For automatic light/dark switching with the system:

```
theme = light:GruvboxLight,dark:GruvboxDark
```

## Fonts

Install a **Nerd Font** before using this setup. starship's prompt symbols and `eza --icons` draw
glyphs from the private-use area. Without a Nerd Font they render as boxes or blank space.

| Font | Role |
|---|---|
| JetBrainsMono Nerd Font | primary — terminal and editors |
| MesloLG Nerd Font | fallback; some themes and prompt presets assume it |

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

**Failure mode:** the config names a font that is not installed. The terminal falls back to Menlo
silently, and everything looks *almost* right except the glyphs. `scripts/doctor.sh` checks for this
mismatch by name.

After installing a font, restart any running terminal app. Each one caches the font list at launch.

## Alternatives considered

| Terminal | Verdict |
|---|---|
| Ghostty | chosen. Fast, native, plain-text config, actively developed |
| iTerm2 | mature and capable. Its config lives in a plist that is painful to track in git |
| Alacritty | fast. No tabs or splits without a multiplexer |
| Terminal.app | fine for a rescue shell. Weak colour and font handling |
| WezTerm | strong feature set. Its Lua config is more machinery than this setup needs |
