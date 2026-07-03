# Post Install Omarchy

Automation for rebuilding my Omarchy desktop after a fresh install.

It applies the same core customization used on my current machine: Omarchy Kali Linux theme, Zsh + Oh My Zsh + Powerlevel10k, dynamic shell colors from Omarchy themes, Fastfetch, tmux, Waybar sizing, terminal configs, Hyprland monitor/workspace setup, and theme hooks.

## Install

Clone and run:

```bash
git clone https://github.com/castarrillo/post-install-omarchy.git ~/Projects/post-install-omarchy
cd ~/Projects/post-install-omarchy
./install.sh
```

Skip package installation:

```bash
./install.sh --skip-packages
```

Also apply the Plymouth/unlock screen:

```bash
./install.sh --with-plymouth
```

The Plymouth step requires sudo and should be run in a real terminal.

## What It Configures

- Installs optional packages and apps through `omarchy pkg install` when available.
- Clones `omarchy-kali-linux` into `~/.config/omarchy/themes/omarchy-kali-linux`.
- Applies the theme as `Omarchy Kali Linux`.
- Removes old local `kali-linux` and `kali-linux2` theme folders.
- Installs Oh My Zsh, Powerlevel10k, and `zsh-autocomplete`.
- Writes `.zshrc` and `.p10k.zsh`.
- Adds dynamic shell color generation from `~/.config/omarchy/current/theme/colors.toml`.
- Adds an Omarchy `theme-set` hook so shell colors reload on theme changes.
- Configures Fastfetch with hardware/software sections and shell info below terminal info.
- Configures tmux with `C-Space` and `C-b` prefixes plus Kali theme sourcing.
- Configures Waybar font/icon sizing, workspace layout and tray.
- Configures Hyprland monitor layout and independent per-monitor workspace ranges.
- Configures Alacritty, Kitty, Ghostty and Foot with JetBrainsMono Nerd Font at size 12.
- Adds Kitty window/tab shortcuts from `auto-bspwm`: `Ctrl+Shift+Enter`, `Ctrl+Shift+T`, `Ctrl+Shift+Z`, and `Ctrl+Arrow`.

## Safety

- Does not edit `~/.local/share/omarchy`.
- Backs up overwritten files to:

```text
~/.local/state/post-install-omarchy/backups/<timestamp>/
```

- Can be re-run. Existing Git clones are updated when possible.

## Theme Repo

The theme is pulled from:

```text
https://github.com/castarrillo/omarchy-kali-linux.git
```

Override it with:

```bash
THEME_REPO=https://github.com/you/your-theme.git ./install.sh
```

## Manual Follow-Up

Set Zsh as the login shell if needed:

```bash
chsh -s $(command -v zsh)
```

Apply Plymouth/unlock later:

```bash
omarchy plymouth set-by-theme omarchy-kali-linux
```

## Notes

Monitor names are specific to my laptop, office monitors and home monitors. Unknown monitors fall back to `preferred,auto,1`.

Some application bindings assume these tools/apps exist: Spotify, Signal, Obsidian, Typora, 1Password, lazydocker, cliamp and the Omarchy launch helpers.

Package/app installation is best-effort. If a package is unavailable in your configured repositories, the script warns and continues with the rest of the setup.
