#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.local/state/post-install-omarchy/backups/$(date +%Y%m%d-%H%M%S)"
THEME_REPO="${THEME_REPO:-https://github.com/castarrillo/omarchy-kali-linux.git}"
THEME_NAME="omarchy-kali-linux"
THEME_DISPLAY="Omarchy Kali Linux"
INSTALL_PACKAGES=1
APPLY_PLYMOUTH=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --skip-packages      Do not install packages
  --with-plymouth      Apply Omarchy Plymouth/unlock theme (requires sudo)
  --help               Show this help

Environment:
  THEME_REPO           Theme repository URL
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-packages) INSTALL_PACKAGES=0 ;;
    --with-plymouth) APPLY_PLYMOUTH=1 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*"; }

backup_path() {
  local target="$1"
  [[ -e "$target" || -L "$target" ]] || return 0
  local rel="${target#$HOME/}"
  mkdir -p "$BACKUP_ROOT/$(dirname "$rel")"
  cp -a "$target" "$BACKUP_ROOT/$rel"
}

write_file() {
  local target="$1"
  local mode="${2:-0644}"
  mkdir -p "$(dirname "$target")"
  backup_path "$target"
  cat > "$target"
  chmod "$mode" "$target"
}

install_packages() {
  [[ "$INSTALL_PACKAGES" == 1 ]] || { warn "Skipping package installation"; return; }
  if ! command -v omarchy >/dev/null 2>&1; then
    warn "omarchy command not found; skipping packages"
    return
  fi

  local packages=(
    zsh git curl jq tmux fastfetch fzf eza bat zoxide mise
    alacritty kitty ghostty foot
    zsh-syntax-highlighting
    btop cava zellij nautilus pamixer xclip
    docker docker-compose lazydocker
    signal-desktop obsidian spotify-launcher typora 1password cliamp
  )

  log "Installing packages"
  if omarchy pkg install --help >/dev/null 2>&1; then
    local package
    for package in "${packages[@]}"; do
      omarchy pkg install "$package" || warn "Could not install package/app: $package"
    done
  else
    warn "Could not detect omarchy pkg install support"
  fi
}

install_zsh_stack() {
  log "Installing Zsh, Oh My Zsh, Powerlevel10k and autocomplete"

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  fi

  if [[ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  fi

  if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autocomplete" ]]; then
    git clone --depth=1 https://github.com/marlonrichert/zsh-autocomplete.git \
      "$HOME/.oh-my-zsh/custom/plugins/zsh-autocomplete"
  fi

  write_file "$HOME/.p10k.zsh" <<'EOF'
[[ -f "$HOME/.config/shell/p10k-omarchy.zsh" ]] && source "$HOME/.config/shell/p10k-omarchy.zsh"
EOF

  write_file "$HOME/.zshrc" <<'EOF'
# If not running interactively, don't do anything.
[[ -o interactive ]] || return

# Omarchy/user paths.
export OMARCHY_PATH="$HOME/.local/share/omarchy"
export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# Oh My Zsh.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
DISABLE_MAGIC_FUNCTIONS="true"
plugins=(git sudo fzf)

[[ -f "$HOME/.config/shell/current-theme.zsh" ]] && source "$HOME/.config/shell/current-theme.zsh"

source "$ZSH/oh-my-zsh.sh"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
[[ -f "$HOME/.config/shell/theme-loader.zsh" ]] && source "$HOME/.config/shell/theme-loader.zsh"

# History: persistent, timestamped and shared across terminals.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# Live history/completion menu below the prompt, similar to Fish.
zstyle ':autocomplete:*' min-input 1
zstyle ':autocomplete:*' list-lines 10
zstyle ':autocomplete:history-search:*' list-lines 10
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Keybindings.
bindkey -e
bindkey '^U' backward-kill-line
bindkey '^[[3~' delete-char
bindkey '^[[1;3C' forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# Tool integrations.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
fi

if [[ -f /usr/share/fzf/completion.zsh ]]; then
  source /usr/share/fzf/completion.zsh
fi

[[ -f "$HOME/.config/shell/current-theme.zsh" ]] && source "$HOME/.config/shell/current-theme.zsh"

if [[ -f "$ZSH/custom/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]]; then
  source "$ZSH/custom/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
fi

if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Omarchy-style aliases.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

alias catn='/usr/bin/cat'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='opencode'
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'

mkcd() {
  mkdir -p "$1" && cd "$1"
}

mkt() {
  mkdir -p nmap content exploits scripts
  echo "Created: nmap content exploits scripts"
}

extractPorts() {
  local file="$1"
  local ports ip
  ports="$(grep -oP '\d{1,5}/open' "$file" | awk '{print $1}' FS='/' | xargs | tr ' ' ',')"
  ip="$(grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$file" | sort -u | head -n 1)"
  echo -e "\n[*] IP Address: $ip"
  echo -e "[*] Open ports: $ports\n"
  echo -n "$ports" | xclip -sel clip 2>/dev/null && echo "[*] Ports copied to clipboard"
}

# Keep Omarchy's terminal welcome behavior.
fastfetch 2>/dev/null || true
EOF
}

install_shell_theme() {
  log "Installing dynamic Omarchy shell theme integration"

  write_file "$HOME/.config/shell/generate-omarchy-theme.sh" 0755 <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

theme_dir="${1:-$HOME/.config/omarchy/current/theme}"
colors_file="$theme_dir/colors.toml"
output_file="$HOME/.config/shell/current-theme.zsh"

get_color() {
  local key="$1"
  local fallback="$2"

  if [[ -f "$colors_file" ]]; then
    local value
    value=$(grep -E "^[[:space:]]*$key[[:space:]]*=" "$colors_file" | tail -n 1 || true)
    value="${value#*=}"
    value="${value//[[:space:]]/}"
    value="${value//\"/}"
    value="${value//\'/}"
    [[ -n "$value" ]] && printf '%s' "$value" && return
  fi

  printf '%s' "$fallback"
}

mkdir -p "$(dirname "$output_file")"

background=$(get_color background '#141C21')
surface=$(get_color bg '#1a1730')
selection=$(get_color selection '#252d3d')
foreground=$(get_color foreground '#c6c6e1')
bright=$(get_color bright_fg '#e8e8f5')
muted=$(get_color muted '#3d4a5c')
accent=$(get_color accent '#6161DB')
blue=$(get_color blue '#6161DB')
magenta=$(get_color magenta '#975FCF')
cyan=$(get_color cyan '#3A9DEB')
yellow=$(get_color yellow '#A859AB')
red=$(get_color red '#3C5ABC')
green=$(get_color green '#669ADE')

cat > "$output_file" <<THEME
# Generated from Omarchy theme colors. Do not edit directly.
typeset -g OMARCHY_SHELL_THEME_DIR="$theme_dir"
typeset -g OMARCHY_SHELL_COLOR_BACKGROUND="$background"
typeset -g OMARCHY_SHELL_COLOR_SURFACE="$surface"
typeset -g OMARCHY_SHELL_COLOR_SELECTION="$selection"
typeset -g OMARCHY_SHELL_COLOR_FOREGROUND="$foreground"
typeset -g OMARCHY_SHELL_COLOR_BRIGHT="$bright"
typeset -g OMARCHY_SHELL_COLOR_MUTED="$muted"
typeset -g OMARCHY_SHELL_COLOR_ACCENT="$accent"
typeset -g OMARCHY_SHELL_COLOR_BLUE="$blue"
typeset -g OMARCHY_SHELL_COLOR_MAGENTA="$magenta"
typeset -g OMARCHY_SHELL_COLOR_CYAN="$cyan"
typeset -g OMARCHY_SHELL_COLOR_YELLOW="$yellow"
typeset -g OMARCHY_SHELL_COLOR_RED="$red"
typeset -g OMARCHY_SHELL_COLOR_GREEN="$green"

typeset -g ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=$muted"
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]="fg=$accent,bold"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=$accent,bold"
ZSH_HIGHLIGHT_STYLES[function]="fg=$magenta,bold"
ZSH_HIGHLIGHT_STYLES[alias]="fg=$magenta"
ZSH_HIGHLIGHT_STYLES[path]="fg=$cyan,underline"
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=$green"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=$green"
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=$green"
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]="fg=$yellow"
ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=$foreground"
ZSH_HIGHLIGHT_STYLES[redirection]="fg=$cyan"
ZSH_HIGHLIGHT_STYLES[globbing]="fg=$cyan"
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=$red,underline"
ZSH_HIGHLIGHT_STYLES[comment]="fg=$muted,italic"
THEME

touch "$output_file"
EOF

  write_file "$HOME/.config/shell/p10k-omarchy.zsh" <<'EOF'
# Powerlevel10k theme driven by ~/.config/shell/current-theme.zsh.

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob
  [[ -f "$HOME/.config/shell/current-theme.zsh" ]] && source "$HOME/.config/shell/current-theme.zsh"
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'
  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return

  local bg=${OMARCHY_SHELL_COLOR_BACKGROUND:-#141C21}
  local surface=${OMARCHY_SHELL_COLOR_SURFACE:-#1a1730}
  local selection=${OMARCHY_SHELL_COLOR_SELECTION:-#252d3d}
  local fg=${OMARCHY_SHELL_COLOR_FOREGROUND:-#c6c6e1}
  local bright=${OMARCHY_SHELL_COLOR_BRIGHT:-#e8e8f5}
  local muted=${OMARCHY_SHELL_COLOR_MUTED:-#3d4a5c}
  local accent=${OMARCHY_SHELL_COLOR_ACCENT:-#6161DB}
  local magenta=${OMARCHY_SHELL_COLOR_MAGENTA:-#975FCF}
  local cyan=${OMARCHY_SHELL_COLOR_CYAN:-#3A9DEB}
  local yellow=${OMARCHY_SHELL_COLOR_YELLOW:-#A859AB}
  local red=${OMARCHY_SHELL_COLOR_RED:-#3C5ABC}

  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir node_version go_version rust_version dotnet_version php_version java_version vcs status command_execution_time newline prompt_char)
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
  typeset -g POWERLEVEL9K_OS_ICON_CONTENT_EXPANSION=''
  typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND="$surface"
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND="$accent"
  typeset -g POWERLEVEL9K_DIR_BACKGROUND="$accent"
  typeset -g POWERLEVEL9K_DIR_FOREGROUND="$bright"
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND="$fg"
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND="$bright"
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=40
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false

  typeset -g POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_NODE_VERSION_BACKGROUND="$magenta"
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND="$bright"
  typeset -g POWERLEVEL9K_NODE_VERSION_VISUAL_IDENTIFIER_EXPANSION=''
  typeset -g POWERLEVEL9K_NODE_VERSION_PREFIX='node '
  typeset -g POWERLEVEL9K_GO_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_GO_VERSION_BACKGROUND="$cyan"
  typeset -g POWERLEVEL9K_GO_VERSION_FOREGROUND="$bg"
  typeset -g POWERLEVEL9K_GO_VERSION_VISUAL_IDENTIFIER_EXPANSION=''
  typeset -g POWERLEVEL9K_GO_VERSION_PREFIX='go '
  typeset -g POWERLEVEL9K_RUST_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_RUST_VERSION_BACKGROUND="$yellow"
  typeset -g POWERLEVEL9K_RUST_VERSION_FOREGROUND="$bright"
  typeset -g POWERLEVEL9K_RUST_VERSION_VISUAL_IDENTIFIER_EXPANSION=''
  typeset -g POWERLEVEL9K_RUST_VERSION_PREFIX='rust '
  typeset -g POWERLEVEL9K_DOTNET_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_DOTNET_VERSION_BACKGROUND="$selection"
  typeset -g POWERLEVEL9K_DOTNET_VERSION_FOREGROUND="$cyan"
  typeset -g POWERLEVEL9K_DOTNET_VERSION_VISUAL_IDENTIFIER_EXPANSION='󰪮'
  typeset -g POWERLEVEL9K_DOTNET_VERSION_PREFIX='.net '
  typeset -g POWERLEVEL9K_PHP_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_PHP_VERSION_BACKGROUND="$selection"
  typeset -g POWERLEVEL9K_PHP_VERSION_FOREGROUND="$magenta"
  typeset -g POWERLEVEL9K_PHP_VERSION_VISUAL_IDENTIFIER_EXPANSION=''
  typeset -g POWERLEVEL9K_PHP_VERSION_PREFIX='php '
  typeset -g POWERLEVEL9K_JAVA_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_JAVA_VERSION_FULL=false
  typeset -g POWERLEVEL9K_JAVA_VERSION_BACKGROUND="$selection"
  typeset -g POWERLEVEL9K_JAVA_VERSION_FOREGROUND="$yellow"
  typeset -g POWERLEVEL9K_JAVA_VERSION_VISUAL_IDENTIFIER_EXPANSION=''
  typeset -g POWERLEVEL9K_JAVA_VERSION_PREFIX='java '

  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=' '
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND="$cyan"
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND="$bright"
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND="$yellow"
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND="$bright"
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND="$selection"
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND="$fg"
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND="$red"
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND="$bright"
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND="$red"
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND="$bright"
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=2
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND="$selection"
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND="$yellow"
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND="$accent"
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND="$red"
  typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'
  builtin unset -m 'P9K_INSTANT_PROMPT'
} "$@"

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
EOF

  write_file "$HOME/.config/shell/theme-loader.zsh" <<'EOF'
# Runtime loader for Omarchy-driven shell colors.
typeset -g OMARCHY_SHELL_THEME_FILE="$HOME/.config/shell/current-theme.zsh"
typeset -g OMARCHY_SHELL_THEME_MTIME=0

omarchy_shell_theme_reload() {
  [[ -f "$OMARCHY_SHELL_THEME_FILE" ]] || return 0
  local current_mtime
  current_mtime=$(stat -c %Y "$OMARCHY_SHELL_THEME_FILE" 2>/dev/null || echo 0)
  [[ "$current_mtime" == "$OMARCHY_SHELL_THEME_MTIME" ]] && return 0
  OMARCHY_SHELL_THEME_MTIME="$current_mtime"
  source "$OMARCHY_SHELL_THEME_FILE"
  if [[ -n ${POWERLEVEL9K_MODE-} && -f "$HOME/.config/shell/p10k-omarchy.zsh" ]]; then
    source "$HOME/.config/shell/p10k-omarchy.zsh"
    p10k reload 2>/dev/null || true
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd omarchy_shell_theme_reload
omarchy_shell_theme_reload
EOF
}

install_theme() {
  log "Installing Omarchy Kali Linux theme"
  local theme_dir="$HOME/.config/omarchy/themes/$THEME_NAME"
  mkdir -p "$HOME/.config/omarchy/themes"
  rm -rf "$HOME/.config/omarchy/themes/kali-linux" "$HOME/.config/omarchy/themes/kali-linux2"
  if [[ -d "$theme_dir/.git" ]]; then
    git -C "$theme_dir" pull --ff-only || warn "Could not update $theme_dir"
  elif [[ -e "$theme_dir" ]]; then
    backup_path "$theme_dir"
    rm -rf "$theme_dir"
    git clone "$THEME_REPO" "$theme_dir"
  else
    git clone "$THEME_REPO" "$theme_dir"
  fi
}

install_theme_hooks() {
  log "Installing Omarchy hooks"
  write_file "$HOME/.config/omarchy/hooks/theme-set.d/shell-theme" 0755 <<'EOF'
#!/bin/bash
# Regenerate the Zsh/Powerlevel10k color layer whenever Omarchy changes theme.
"$HOME/.config/shell/generate-omarchy-theme.sh" "$HOME/.config/omarchy/current/theme"
EOF

  write_file "$HOME/.config/omarchy/hooks/theme-set.d/auto-wallpaper" 0755 <<'EOF'
#!/bin/bash
# If auto-wallpaper is enabled, re-apply a random wallpaper after a theme change.
TOGGLE="$HOME/.local/state/omarchy/toggles/auto-wallpaper"
[[ ! -f "$TOGGLE" ]] && exit 0
sleep 0.5
omarchy-wallpaper-auto-change
EOF
}

install_terminals() {
  log "Installing terminal configs"
  write_file "$HOME/.config/alacritty/alacritty.toml" <<'EOF'
general.import = [ "~/.config/omarchy/current/theme/alacritty.toml" ]

[env]
TERM = "xterm-256color"

[terminal]
osc52 = "CopyPaste"

[font]
normal = { family = "JetBrainsMono Nerd Font" }
bold = { family = "JetBrainsMono Nerd Font" }
italic = { family = "JetBrainsMono Nerd Font" }
size = 12

[window]
padding.x = 14
padding.y = 14
decorations = "None"

[keyboard]
bindings = [
{ key = "Insert", mods = "Shift", action = "Paste" },
{ key = "Insert", mods = "Control", action = "Copy" },
{ key = "Return", mods = "Shift", chars = "\u001B\r" }
]
EOF

  write_file "$HOME/.config/kitty/kitty.conf" <<'EOF'
include ~/.config/omarchy/current/theme/kitty.conf
font_family JetBrainsMono Nerd Font
bold_italic_font auto
font_size 12.0
window_padding_width 14
hide_window_decorations yes
confirm_os_window_close 0
map ctrl+insert copy_to_clipboard
map shift+insert paste_from_clipboard
map ctrl+left neighboring_window left
map ctrl+right neighboring_window right
map ctrl+up neighboring_window up
map ctrl+down neighboring_window down
map ctrl+shift+z toggle_layout stack
map ctrl+shift+enter new_window_with_cwd
map ctrl+shift+t new_tab_with_cwd
allow_remote_control yes
cursor_shape block
cursor_blink_interval 0
shell_integration no-cursor
enable_audio_bell no
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
tab_title_template {title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}
EOF

  write_file "$HOME/.config/ghostty/config" <<'EOF'
config-file = ?"~/.config/omarchy/current/theme/ghostty.conf"
font-family = "JetBrainsMono Nerd Font"
font-style = Regular
font-size = 12
window-theme = ghostty
window-padding-x = 14
window-padding-y = 14
confirm-close-surface=false
resize-overlay = never
gtk-toolbar-style = flat
cursor-style = "block"
cursor-style-blink = false
shell-integration-features = no-cursor,ssh-env
keybind = shift+insert=paste_from_clipboard
keybind = control+insert=copy_to_clipboard
keybind = super+control+shift+alt+arrow_down=resize_split:down,100
keybind = super+control+shift+alt+arrow_up=resize_split:up,100
keybind = super+control+shift+alt+arrow_left=resize_split:left,100
keybind = super+control+shift+alt+arrow_right=resize_split:right,100
mouse-scroll-multiplier = 0.95
async-backend = epoll
EOF

  write_file "$HOME/.config/foot/foot.ini" <<'EOF'
[main]
include=~/.config/omarchy/current/theme/foot.ini
term=xterm-256color
font=JetBrainsMono Nerd Font:size=12
pad=14x14
initial-window-mode=windowed
workers=0

[scrollback]
lines=10000

[cursor]
style=block
blink=no

[key-bindings]
clipboard-copy=Control+Insert
primary-paste=none
clipboard-paste=Shift+Insert
EOF
}

install_fastfetch() {
  log "Installing Fastfetch config"
  write_file "$HOME/.config/fastfetch/config.jsonc" <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "type": "file", "source": "~/.config/omarchy/branding/about.txt", "color": { "1": "green" }, "padding": { "top": 2, "right": 6, "left": 2 } },
  "modules": [
    "break",
    { "type": "custom", "format": "\u001b[90m┌──────────────────────Hardware──────────────────────┐" },
    { "type": "host", "key": " PC", "keyColor": "green" },
    { "type": "cpu", "key": "│ ├", "showPeCoreCount": true, "keyColor": "green" },
    { "type": "gpu", "key": "│ ├", "detectionMethod": "pci", "keyColor": "green" },
    { "type": "display", "key": "│ ├󱄄", "keyColor": "green" },
    { "type": "disk", "key": "│ ├󰋊", "keyColor": "green" },
    { "type": "memory", "key": "│ ├", "keyColor": "green" },
    { "type": "swap", "key": "└ └󰓡 ", "keyColor": "green" },
    { "type": "custom", "format": "\u001b[90m└────────────────────────────────────────────────────┘" },
    "break",
    { "type": "custom", "format": "\u001b[90m┌──────────────────────Software──────────────────────┐" },
    { "type": "command", "key": "\ue900 OS", "keyColor": "blue", "text": "version=$(omarchy-version); echo \"Omarchy $version\"" },
    { "type": "command", "key": "│ ├󰘬", "keyColor": "blue", "text": "branch=$(omarchy-version-branch); echo \"$branch\"" },
    { "type": "command", "key": "│ ├󰔫", "keyColor": "blue", "text": "channel=$(omarchy-version-channel); echo \"$channel\"" },
    { "type": "kernel", "key": "│ ├", "keyColor": "blue" },
    { "type": "wm", "key": "│ ├", "keyColor": "blue" },
    { "type": "terminal", "key": "│ ├", "keyColor": "blue" },
    { "type": "command", "key": "│ ├", "keyColor": "blue", "text": "shell=$(basename \"$SHELL\"); version=$($shell --version 2>/dev/null | head -n 1); echo \"${version:-$shell}\"" },
    { "type": "packages", "key": "│ ├󰏖", "keyColor": "blue" },
    { "type": "command", "key": "│ ├󰸌", "keyColor": "blue", "text": "theme=$(omarchy-theme-current); echo -e \"$theme \\e[38m●\\e[37m●\\e[36m●\\e[35m●\\e[34m●\\e[33m●\\e[32m●\\e[31m●\"" },
    { "type": "terminalfont", "key": "└ └", "keyColor": "blue" },
    { "type": "custom", "format": "\u001b[90m└────────────────────────────────────────────────────┘" },
    "break",
    { "type": "custom", "format": "\u001b[90m┌────────────────Age / Uptime / Update───────────────┐" },
    { "type": "command", "key": "󱦟 OS Age", "keyColor": "magenta", "text": "echo $(( ($(date +%s) - $(stat -c %W /)) / 86400 )) days" },
    { "type": "uptime", "key": "󱫐 Uptime", "keyColor": "magenta" },
    { "type": "command", "key": " Update", "keyColor": "magenta", "text": "updated=$(omarchy-version-pkgs); echo \"$updated\"" },
    { "type": "custom", "format": "\u001b[90m└────────────────────────────────────────────────────┘" },
    "break"
  ]
}
EOF
}

install_tmux() {
  log "Installing tmux config"
  write_file "$HOME/.config/tmux/tmux.conf" <<'EOF'
# Prefix
set -g prefix C-Space
set -g prefix2 C-b
bind C-Space send-prefix

# Config and help
bind q source-file ~/.config/tmux/tmux.conf \; display "Configuration reloaded"
bind ? display-popup -E -w 80% -h 70% -T "Tmux keybindings" "omarchy-menu-tmux-keybindings --print | less -R"

# Vi mode for copy
setw -g mode-keys vi
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel

# Pane Controls
bind -n M-Enter split-window -v -c "#{pane_current_path}"
bind -n M-S-Enter split-window -h -c "#{pane_current_path}"
bind -n M-Escape kill-pane
bind h split-window -v -c "#{pane_current_path}"
bind v split-window -h -c "#{pane_current_path}"
bind x kill-pane
bind -n C-M-Left select-pane -L
bind -n C-M-Right select-pane -R
bind -n C-M-Up select-pane -U
bind -n C-M-Down select-pane -D
bind -n C-M-S-Left resize-pane -L 5
bind -n C-M-S-Down resize-pane -D 5
bind -n C-M-S-Up resize-pane -U 5
bind -n C-M-S-Right resize-pane -R 5

# Window navigation
bind r command-prompt -I "#W" "rename-window -- '%%'"
bind c new-window -c "#{pane_current_path}"
bind k kill-window
bind -n M-1 select-window -t 1
bind -n M-2 select-window -t 2
bind -n M-3 select-window -t 3
bind -n M-4 select-window -t 4
bind -n M-5 select-window -t 5
bind -n M-6 select-window -t 6
bind -n M-7 select-window -t 7
bind -n M-8 select-window -t 8
bind -n M-9 select-window -t 9
bind -n M-Left select-window -t -1
bind -n M-Right select-window -t +1
bind -n M-S-Left swap-window -t -1 \; select-window -t -1
bind -n M-S-Right swap-window -t +1 \; select-window -t +1

# Session controls
bind R command-prompt -I "#S" "rename-session -- '%%'"
bind C new-session -c "#{pane_current_path}"
bind K kill-session
bind P switch-client -p
bind N switch-client -n
bind -n M-Up switch-client -p
bind -n M-Down switch-client -n

# General
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",*:RGB"
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 50000
set -g escape-time 0
set -g focus-events on
set -g set-clipboard on
set -g allow-passthrough on
setw -g aggressive-resize on
set -g detach-on-destroy off
set -g extended-keys on
set -g extended-keys-format csi-u
set -sg escape-time 10

# Status bar defaults
set -g status-position top
set -g status-interval 5
set -g status-left-length 30
set -g status-right-length 50
set -g window-status-separator ""
set -gw automatic-rename on
set -gw automatic-rename-format '#{b:pane_current_path}'

# Theme fallback
set -g status-style "bg=default,fg=default"
set -g status-left "#[fg=black,bg=blue,bold] #S #[bg=default] "
set -g status-right "#[fg=blue]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}#[fg=brightblack]#h "
set -g window-status-format "#[fg=brightblack] #I:#W "
set -g window-status-current-format "#[fg=blue,bold] #I:#W "
set -g pane-border-style "fg=brightblack"
set -g pane-active-border-style "fg=blue"
set -g message-style "bg=default,fg=blue"
set -g message-command-style "bg=default,fg=blue"
set -g mode-style "bg=blue,fg=black"
setw -g clock-mode-colour blue

# Active Omarchy theme. Keep this last so themes never replace keybindings.
source-file -q ~/.config/omarchy/current/theme/tmux.conf
EOF
}

install_waybar() {
  log "Installing Waybar config"
  write_file "$HOME/.config/waybar/style.css" <<'EOF'
@import "../omarchy/current/theme/waybar.css";

* {
  background-color: @background;
  color: @foreground;
  border: none;
  border-radius: 0;
  min-height: 0;
  font-family: 'JetBrainsMono Nerd Font';
  font-size: 18px;
}

.modules-left { margin-left: 11px; }
.modules-right { margin-right: 11px; }

#workspaces button {
  all: initial;
  padding: 0 8px;
  margin: 0 2px;
  min-width: 12px;
}

#workspaces button.empty { opacity: 0.5; }

#cpu, #battery, #pulseaudio, #custom-omarchy, #custom-update {
  min-width: 16px;
  margin: 0 10px;
}

#tray { margin-right: 21px; }
#bluetooth { margin-right: 23px; }
#network { margin-right: 17px; }
#custom-expand-icon { margin-right: 24px; }
tooltip { padding: 3px; }
#custom-update { font-size: 12px; }
#clock { margin-left: 12px; }
#custom-weather { margin-left: 10px; margin-right: 10px; }
#custom-weather.unavailable { min-width: 0; margin: 0; padding: 0; }
.hidden { opacity: 0; }

#custom-screenrecording-indicator,
#custom-idle-indicator,
#custom-notification-silencing-indicator {
  min-width: 16px;
  margin-left: 7px;
  margin-right: 0;
  font-size: 12px;
  padding-bottom: 1px;
}

#custom-screenrecording-indicator.active,
#custom-idle-indicator.active,
#custom-notification-silencing-indicator.active { color: #a55555; }
#custom-voxtype { min-width: 16px; margin: 0 0 0 10px; }
#custom-voxtype.recording { color: #a55555; }
EOF

  write_file "$HOME/.config/waybar/config.jsonc" <<'EOF'
{
  "reload_style_on_change": true,
  "layer": "top",
  "position": "top",
  "spacing": 0,
  "height": 35,
  "modules-left": ["custom/omarchy", "hyprland/workspaces"],
  "modules-center": ["clock", "custom/weather", "custom/update", "custom/voxtype", "custom/screenrecording-indicator", "custom/idle-indicator", "custom/notification-silencing-indicator"],
  "modules-right": ["group/tray-expander", "bluetooth", "network", "pulseaudio", "cpu", "battery"],
  "hyprland/workspaces": {
    "on-click": "activate",
    "format": "{icon}",
    "format-icons": { "default": "", "active": "󱓻", "1": "1", "2": "2", "3": "3", "4": "4", "5": "5", "6": "6", "7": "7", "8": "8", "9": "9", "10": "0", "11": "1", "12": "2", "13": "3", "14": "4", "15": "5", "16": "6", "17": "7", "18": "8", "19": "9", "20": "0", "21": "1", "22": "2", "23": "3", "24": "4", "25": "5", "26": "6", "27": "7", "28": "8", "29": "9", "30": "0" },
    "all-outputs": false,
    "persistent-workspaces": { "eDP-1": [1,2,3,4,5,6,7,8,9,10], "DP-2": [11,12,13,14,15,16,17,18,19,20], "DP-3": [21,22,23,24,25,26,27,28,29,30] }
  },
  "custom/omarchy": { "format": "<span font='omarchy'></span>", "on-click": "omarchy-menu", "on-click-right": "xdg-terminal-exec", "tooltip-format": "Omarchy Menu\n\nSuper + Alt + Space" },
  "custom/update": { "format": "", "exec": "omarchy-update-available", "on-click": "omarchy-launch-floating-terminal-with-presentation omarchy-update", "tooltip-format": "Omarchy update available", "signal": 7, "interval": 21600 },
  "cpu": { "interval": 5, "format": "󰍛", "on-click": "omarchy-launch-or-focus-tui btop", "on-click-right": "alacritty" },
  "clock": { "format": "{:L%A %H:%M}", "format-alt": "{:L%d %B W%V %Y}", "tooltip": false, "on-click-right": "omarchy-launch-floating-terminal-with-presentation omarchy-tz-select" },
  "custom/weather": { "exec": "$OMARCHY_PATH/default/waybar/weather.sh", "return-type": "json", "interval": 60, "tooltip": false, "on-click": "notify-send -u low \"$(omarchy-weather-status)\"" },
  "network": { "format-icons": ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"], "format": "{icon}", "format-wifi": "{icon}", "format-ethernet": "󰀂", "format-disconnected": "󰤮", "tooltip-format-wifi": "{essid} ({frequency} GHz)", "tooltip-format-ethernet": "Connected", "tooltip-format-disconnected": "Disconnected", "interval": 3, "spacing": 1, "on-click": "omarchy-launch-wifi" },
  "battery": { "format": "{capacity}% {icon}", "format-discharging": "{icon}", "format-charging": "{icon}", "format-plugged": "", "format-icons": { "charging": ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"], "default": ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"] }, "format-full": "󰂅", "tooltip-format-discharging": "{power:>1.0f}W↓ {capacity}%", "tooltip-format-charging": "{power:>1.0f}W↑ {capacity}%", "interval": 5, "on-click": "omarchy-menu power", "on-click-right": "notify-send -u low \"$(omarchy-battery-status)\"", "states": { "warning": 20, "critical": 10 } },
  "bluetooth": { "format": "", "format-off": "󰂲", "format-disabled": "󰂲", "format-connected": "󰂱", "format-no-controller": "", "tooltip-format": "Devices connected: {num_connections}", "on-click": "omarchy-launch-bluetooth" },
  "pulseaudio": { "format": "{icon}", "on-click": "omarchy-launch-audio", "on-click-right": "pamixer -t", "tooltip-format": "Playing at {volume}%", "scroll-step": 5, "format-muted": "", "format-icons": { "headphone": "", "headset": "", "default": ["", "", ""] } },
  "group/tray-expander": { "orientation": "inherit", "drawer": { "transition-duration": 600, "children-class": "tray-group-item" }, "modules": ["custom/expand-icon", "tray"] },
  "custom/expand-icon": { "format": "", "tooltip": false, "on-scroll-up": "", "on-scroll-down": "", "on-scroll-left": "", "on-scroll-right": "" },
  "custom/screenrecording-indicator": { "on-click": "omarchy-capture-screenrecording", "exec": "$OMARCHY_PATH/default/waybar/indicators/screen-recording.sh", "signal": 8, "return-type": "json" },
  "custom/idle-indicator": { "on-click": "omarchy-toggle-idle", "exec": "$OMARCHY_PATH/default/waybar/indicators/idle.sh", "signal": 9, "return-type": "json" },
  "custom/notification-silencing-indicator": { "on-click": "omarchy-toggle-notification-silencing", "exec": "$OMARCHY_PATH/default/waybar/indicators/notification-silencing.sh", "signal": 10, "return-type": "json" },
  "custom/voxtype": { "exec": "omarchy-voxtype-status", "return-type": "json", "format": "{icon}", "format-icons": { "idle": "", "recording": "󰍬", "transcribing": "󰔟" }, "tooltip": true, "on-click-right": "omarchy-voxtype-config", "on-click": "omarchy-voxtype-model" },
  "tray": { "icon-size": 18, "spacing": 23 }
}
EOF
}

install_hyprland() {
  log "Installing Hyprland monitor/workspace config"
  write_file "$HOME/.config/hypr/monitors.conf" <<'EOF'
# See https://wiki.hypr.land/Configuring/Basics/Monitors/
env = GDK_SCALE,2

# Laptop
monitor = eDP-1, 1920x1080@60, 0x1080, 1

# Office monitors matched by EDID description.
monitor = desc:Samsung Electric Company LF24T35 HCNTC00457, 1920x1080@75, 0x0, 1
monitor = desc:Lenovo Group Limited E22-28 VY537647, 1920x1080@75, 1920x0, 1

# Home monitors matched by EDID description.
monitor = desc:LG Electronics LG FULL HD, 1920x1080@75, 0x0, 1
monitor = desc:LG Electronics LG TV, 1280x720@60, 1920x0, 1

# Catch-all for new/unknown monitors.
monitor = ,preferred,auto,1
EOF

  write_file "$HOME/.config/hypr/scripts/workspace.sh" 0755 <<'EOF'
#!/bin/bash
ACTION=$1
BASE=$2
if [[ -z $ACTION ]] || [[ -z $BASE ]]; then
  echo "Usage: $0 switch|move|move-silent <1-10>"
  exit 1
fi

MONITORS=$(hyprctl monitors -j | jq 'sort_by(.id)')
FOCUSED_NAME=$(echo "$MONITORS" | jq -r '.[] | select(.focused == true) | .name')
MONITOR_INDEX=$(echo "$MONITORS" | jq -r 'to_entries | .[] | select(.value.name == $name) | .key' --arg name "$FOCUSED_NAME")
OFFSET=$((MONITOR_INDEX * 10))
WORKSPACE=$((BASE + OFFSET))

case $ACTION in
  switch) hyprctl dispatch focusworkspaceoncurrentmonitor "$WORKSPACE" ;;
  move) hyprctl dispatch movetoworkspace "$WORKSPACE" ;;
  move-silent) hyprctl dispatch movetoworkspacesilent "$WORKSPACE" ;;
  *) echo "Unknown action: $ACTION" >&2; exit 1 ;;
esac
EOF

  write_file "$HOME/.config/hypr/scripts/workspace-recall.sh" 0755 <<'EOF'
#!/bin/bash
PRIMARY_WS_MAX=10
LOG="$HOME/.cache/hypr-workspace-events.log"
log() { echo "[$(date '+%T')] recall: $*" >> "$LOG"; }
moved=0

while IFS=$'\t' read -r addr ws_id; do
  [[ -z "$addr" ]] && continue
  (( ws_id <= PRIMARY_WS_MAX )) && continue
  slot=$(( (ws_id - 1) % 10 + 1 ))
  log "moving addr=$addr ws=$ws_id -> ws=$slot"
  result=$(hyprctl dispatch movetoworkspace "${slot},address:${addr}" 2>&1)
  log "dispatch result: $result"
  (( moved++ ))
done < <(hyprctl clients -j | jq -r '.[] | [.address, .workspace.id] | @tsv')

if (( moved > 0 )); then
  notify-send -u low "Apps recuperadas" "$moved ventana(s) traídas al monitor principal" -t 4000
else
  notify-send -u low "Sin cambios" "No hay ventanas en workspaces de monitores externos" -t 2000
fi
EOF

  write_file "$HOME/.config/hypr/bindings.conf" <<'EOF'
# Application bindings
bindd = SUPER, RETURN, Terminal, exec, uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"
bindd = SUPER ALT, RETURN, Tmux, exec, uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" bash -c "tmux attach || tmux new -s Work"
bindd = SUPER SHIFT, RETURN, Browser, exec, omarchy-launch-browser
bindd = SUPER SHIFT, F, File manager, exec, uwsm-app -- nautilus --new-window
bindd = SUPER ALT SHIFT, F, File manager (cwd), exec, uwsm-app -- nautilus --new-window "$(omarchy-cmd-terminal-cwd)"
bindd = SUPER SHIFT, B, Browser, exec, omarchy-launch-browser
bindd = SUPER SHIFT ALT, B, Browser (private), exec, omarchy-launch-browser --private
bindd = SUPER SHIFT, M, Music, exec, omarchy-launch-or-focus spotify
bindd = SUPER SHIFT ALT, M, Music TUI, exec, omarchy-launch-or-focus-tui cliamp
bindd = SUPER SHIFT, N, Editor, exec, omarchy-launch-editor
bindd = SUPER SHIFT, D, Docker, exec, omarchy-launch-tui lazydocker
bindd = SUPER SHIFT, G, Signal, exec, omarchy-launch-or-focus ^signal$ "uwsm-app -- signal-desktop"
bindd = SUPER SHIFT, O, Obsidian, exec, omarchy-launch-or-focus ^obsidian$ "uwsm-app -- obsidian"
bindd = SUPER SHIFT, W, Typora, exec, uwsm-app -- typora --enable-wayland-ime
bindd = SUPER SHIFT, SLASH, Passwords, exec, uwsm-app -- 1password
bindd = SUPER SHIFT, A, ChatGPT, exec, omarchy-launch-webapp "https://chatgpt.com"
bindd = SUPER SHIFT ALT, A, Grok, exec, omarchy-launch-webapp "https://grok.com"
bindd = SUPER SHIFT, C, Calendar, exec, omarchy-launch-webapp "https://app.hey.com/calendar/weeks/"
bindd = SUPER SHIFT, E, Email, exec, omarchy-launch-webapp "https://app.hey.com"
bindd = SUPER SHIFT, Y, YouTube, exec, omarchy-launch-webapp "https://youtube.com/"
bindd = SUPER SHIFT ALT, G, WhatsApp, exec, omarchy-launch-or-focus-webapp WhatsApp "https://web.whatsapp.com/"
bindd = SUPER SHIFT CTRL, G, Google Messages, exec, omarchy-launch-or-focus-webapp "Google Messages" "https://messages.google.com/web/conversations"
bindd = SUPER SHIFT, P, Google Photos, exec, omarchy-launch-or-focus-webapp "Google Photos" "https://photos.google.com/"
bindd = SUPER SHIFT, X, X, exec, omarchy-launch-webapp "https://x.com/"
bindd = SUPER SHIFT ALT, X, X Post, exec, omarchy-launch-webapp "https://x.com/compose/post"
bindd = SUPER SHIFT, R, Recall windows from external monitors, exec, bash ~/.config/hypr/scripts/workspace-recall.sh
bindd = SUPER SHIFT ALT, W, Force wallpaper change, exec, omarchy-wallpaper-auto-change && notify-send -u low "󰸉  Nuevo fondo" "El timer sigue en :00 :10 :20..." -t 2500

# Per-monitor independent workspaces.
unbind = SUPER, code:10
unbind = SUPER, code:11
unbind = SUPER, code:12
unbind = SUPER, code:13
unbind = SUPER, code:14
unbind = SUPER, code:15
unbind = SUPER, code:16
unbind = SUPER, code:17
unbind = SUPER, code:18
unbind = SUPER, code:19
unbind = SUPER SHIFT, code:10
unbind = SUPER SHIFT, code:11
unbind = SUPER SHIFT, code:12
unbind = SUPER SHIFT, code:13
unbind = SUPER SHIFT, code:14
unbind = SUPER SHIFT, code:15
unbind = SUPER SHIFT, code:16
unbind = SUPER SHIFT, code:17
unbind = SUPER SHIFT, code:18
unbind = SUPER SHIFT, code:19
unbind = SUPER SHIFT ALT, code:10
unbind = SUPER SHIFT ALT, code:11
unbind = SUPER SHIFT ALT, code:12
unbind = SUPER SHIFT ALT, code:13
unbind = SUPER SHIFT ALT, code:14
unbind = SUPER SHIFT ALT, code:15
unbind = SUPER SHIFT ALT, code:16
unbind = SUPER SHIFT ALT, code:17
unbind = SUPER SHIFT ALT, code:18
unbind = SUPER SHIFT ALT, code:19

bindd = SUPER, code:10, Switch to workspace 1, exec, ~/.config/hypr/scripts/workspace.sh switch 1
bindd = SUPER, code:11, Switch to workspace 2, exec, ~/.config/hypr/scripts/workspace.sh switch 2
bindd = SUPER, code:12, Switch to workspace 3, exec, ~/.config/hypr/scripts/workspace.sh switch 3
bindd = SUPER, code:13, Switch to workspace 4, exec, ~/.config/hypr/scripts/workspace.sh switch 4
bindd = SUPER, code:14, Switch to workspace 5, exec, ~/.config/hypr/scripts/workspace.sh switch 5
bindd = SUPER, code:15, Switch to workspace 6, exec, ~/.config/hypr/scripts/workspace.sh switch 6
bindd = SUPER, code:16, Switch to workspace 7, exec, ~/.config/hypr/scripts/workspace.sh switch 7
bindd = SUPER, code:17, Switch to workspace 8, exec, ~/.config/hypr/scripts/workspace.sh switch 8
bindd = SUPER, code:18, Switch to workspace 9, exec, ~/.config/hypr/scripts/workspace.sh switch 9
bindd = SUPER, code:19, Switch to workspace 10, exec, ~/.config/hypr/scripts/workspace.sh switch 10
bindd = SUPER SHIFT, code:10, Move window to workspace 1, exec, ~/.config/hypr/scripts/workspace.sh move 1
bindd = SUPER SHIFT, code:11, Move window to workspace 2, exec, ~/.config/hypr/scripts/workspace.sh move 2
bindd = SUPER SHIFT, code:12, Move window to workspace 3, exec, ~/.config/hypr/scripts/workspace.sh move 3
bindd = SUPER SHIFT, code:13, Move window to workspace 4, exec, ~/.config/hypr/scripts/workspace.sh move 4
bindd = SUPER SHIFT, code:14, Move window to workspace 5, exec, ~/.config/hypr/scripts/workspace.sh move 5
bindd = SUPER SHIFT, code:15, Move window to workspace 6, exec, ~/.config/hypr/scripts/workspace.sh move 6
bindd = SUPER SHIFT, code:16, Move window to workspace 7, exec, ~/.config/hypr/scripts/workspace.sh move 7
bindd = SUPER SHIFT, code:17, Move window to workspace 8, exec, ~/.config/hypr/scripts/workspace.sh move 8
bindd = SUPER SHIFT, code:18, Move window to workspace 9, exec, ~/.config/hypr/scripts/workspace.sh move 9
bindd = SUPER SHIFT, code:19, Move window to workspace 10, exec, ~/.config/hypr/scripts/workspace.sh move 10
bindd = SUPER SHIFT ALT, code:10, Move window silently to workspace 1, exec, ~/.config/hypr/scripts/workspace.sh move-silent 1
bindd = SUPER SHIFT ALT, code:11, Move window silently to workspace 2, exec, ~/.config/hypr/scripts/workspace.sh move-silent 2
bindd = SUPER SHIFT ALT, code:12, Move window silently to workspace 3, exec, ~/.config/hypr/scripts/workspace.sh move-silent 3
bindd = SUPER SHIFT ALT, code:13, Move window silently to workspace 4, exec, ~/.config/hypr/scripts/workspace.sh move-silent 4
bindd = SUPER SHIFT ALT, code:14, Move window silently to workspace 5, exec, ~/.config/hypr/scripts/workspace.sh move-silent 5
bindd = SUPER SHIFT ALT, code:15, Move window silently to workspace 6, exec, ~/.config/hypr/scripts/workspace.sh move-silent 6
bindd = SUPER SHIFT ALT, code:16, Move window silently to workspace 7, exec, ~/.config/hypr/scripts/workspace.sh move-silent 7
bindd = SUPER SHIFT ALT, code:17, Move window silently to workspace 8, exec, ~/.config/hypr/scripts/workspace.sh move-silent 8
bindd = SUPER SHIFT ALT, code:18, Move window silently to workspace 9, exec, ~/.config/hypr/scripts/workspace.sh move-silent 9
bindd = SUPER SHIFT ALT, code:19, Move window silently to workspace 10, exec, ~/.config/hypr/scripts/workspace.sh move-silent 10
EOF
}

apply_theme_and_services() {
  log "Applying theme and restarting user services"
  if command -v omarchy >/dev/null 2>&1; then
    omarchy theme set "$THEME_DISPLAY" || warn "Could not apply theme"
    omarchy restart waybar || true
    omarchy restart terminal || true
  fi

  "$HOME/.config/shell/generate-omarchy-theme.sh" "$HOME/.config/omarchy/current/theme" || true

  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload || true
    hyprctl configerrors || true
  fi

  if command -v tmux >/dev/null 2>&1; then
    tmux start-server \; source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
  fi

  if [[ "$APPLY_PLYMOUTH" == 1 ]] && command -v omarchy >/dev/null 2>&1; then
    omarchy plymouth set-by-theme "$THEME_NAME"
  fi
}

set_default_shell() {
  if command -v zsh >/dev/null 2>&1 && [[ "${SHELL:-}" != "$(command -v zsh)" ]]; then
    warn "To make Zsh your login shell, run: chsh -s $(command -v zsh)"
  fi
}

main() {
  mkdir -p "$BACKUP_ROOT"
  install_packages
  install_theme
  install_zsh_stack
  install_shell_theme
  install_theme_hooks
  install_terminals
  install_fastfetch
  install_tmux
  install_waybar
  install_hyprland
  apply_theme_and_services
  set_default_shell
  log "Done. Backups stored in $BACKUP_ROOT"
}

main "$@"
