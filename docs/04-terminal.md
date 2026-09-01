# 04 — Terminal & fonts

## Ghostty

Native, GPU-accelerated, config is a plain text file. `~/.config/ghostty/config` is symlinked from
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

**Gotcha: Ghostty applies the _last_ occurrence of a duplicated key.** Declaring
`window-padding-x` twice silently discards the first value, which is exactly how a config drifts
into contradicting itself. Each key appears once in the shipped config; keep it that way.

### Settings worth knowing

| Setting | Why |
|---|---|
| `minimum-contrast = 1.3` | forces legibility on low-contrast theme pairs. `1.0` disables |
| `macos-option-as-alt = left` | left ⌥ sends `Esc+` for readline word-motion; right ⌥ still types `é`/`ø` |
| `font-thicken = true` | macOS-only; compensates for thin stem rendering |
| `keybind = shift+enter=text:\n` | newline instead of submit — required by REPLs and CLI agents |
| `background-opacity = 0.96` | below ~0.9 costs legibility for no real benefit |

### Theme choice

`theme = Gruvbox Dark`. For automatic light/dark switching with the system:

```
theme = light:GruvboxLight,dark:GruvboxDark
```

## Fonts

A **Nerd Font** is not optional here: starship's prompt symbols and `eza --icons` use glyphs from
the private-use area. Without one they render as boxes or blank space.

| Font | Role |
|---|---|
| JetBrainsMono Nerd Font | primary — terminal and editors |
| MesloLG Nerd Font | fallback; some themes and prompt presets assume it |

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

**Failure mode:** the terminal config names a font that is not installed, the terminal silently
falls back to Menlo, and everything looks *almost* right except the glyphs. `scripts/doctor.sh`
checks for this specifically, because it was a real mismatch in the setup this repo was distilled
from — the config asked for JetBrainsMono while only Meslo was installed.

After installing a font, restart already-running terminal apps; they cache the font list at launch.

## Alternatives considered

| Terminal | Verdict |
|---|---|
| Ghostty | chosen — fast, native, plain-text config, actively developed |
| iTerm2 | mature and capable, but config lives in a plist that is painful to version-control |
| Alacritty | fast, but no tabs or splits without a multiplexer |
| Terminal.app | fine for a rescue shell; weak colour and font handling |
| WezTerm | strong feature set; Lua config is more machinery than this setup needs |
