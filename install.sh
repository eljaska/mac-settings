#!/bin/sh
#
# Bootstrap script for a fresh Mac.
# Run with: curl -fsSL https://raw.githubusercontent.com/eljaska/mac-settings/main/install.sh | sh
#       or: sh install.sh
#

set -eu

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

log() {
    printf '\033[1;34m==>\033[0m %s\n' "$*"
}

err() {
    printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
    exit 1
}

# Only macOS for now.
if [ "$(uname -s)" != "Darwin" ]; then
    err "This script currently supports macOS only."
fi

# Xcode Command Line Tools (provides git, clang, make, etc.).
if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode Command Line Tools (a GUI prompt will appear)..."
    xcode-select --install
    printf 'Press Return once the Command Line Tools install has finished... '
    read -r _
else
    log "Xcode Command Line Tools already installed; skipping."
fi

# Homebrew.
if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    log "Homebrew already installed; skipping."
    eval "$(brew shellenv)"
fi

# Homebrew packages from Brewfile.
log "Installing Homebrew packages from Brewfile..."
brew bundle --file="$REPO_ROOT/Brewfile"

# Oh My Zsh. KEEP_ZSHRC prevents it from overwriting/moving ~/.zshrc,
# which we manage via symlink below.
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    log "Oh My Zsh already installed; skipping."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Oh My Zsh custom plugins.
clone_plugin() {
    name="$1"
    url="$2"
    dir="$ZSH_CUSTOM/plugins/$name"
    if [ ! -d "$dir" ]; then
        log "Cloning plugin $name..."
        git clone --depth 1 "$url" "$dir"
    else
        log "Plugin $name already present; skipping."
    fi
}

clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
clone_plugin you-should-use          https://github.com/MichaelAquilina/zsh-you-should-use.git
clone_plugin zsh-bat                 https://github.com/fdellwing/zsh-bat.git
clone_plugin zsh-nvm                 https://github.com/lukechilds/zsh-nvm

# Oh My Zsh emoji theme (custom; symlinked from repo so edits are tracked).
mkdir -p "$ZSH_CUSTOM/themes"
theme_src="$REPO_ROOT/themes/emoji.zsh-theme"
theme_dst="$ZSH_CUSTOM/themes/emoji.zsh-theme"
if [ -L "$theme_dst" ]; then
    rm "$theme_dst"
elif [ -e "$theme_dst" ]; then
    log "Backing up existing $theme_dst -> $theme_dst.backup"
    mv "$theme_dst" "$theme_dst.backup"
fi
ln -s "$theme_src" "$theme_dst"
log "Linked $theme_dst -> $theme_src"

# ~/Developer directory.
if [ ! -d "$HOME/Developer" ]; then
    log "Creating ~/Developer..."
    mkdir -p "$HOME/Developer"
fi

# Symlink dotfiles from repo -> home. Existing non-symlink files are backed up.
link_dotfile() {
    src="$REPO_ROOT/$1"
    dst="$HOME/$2"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        log "Backing up existing $dst -> $dst.backup"
        mv "$dst" "$dst.backup"
    fi
    ln -s "$src" "$dst"
    log "Linked $dst -> $src"
}

link_dotfile zshrc     .zshrc
link_dotfile zprofile  .zprofile
link_dotfile gitconfig .gitconfig

# Claude Code configuration.
link_into() {
    src="$1"
    dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        log "Backing up existing $dst -> $dst.backup"
        mv "$dst" "$dst.backup"
    fi
    ln -s "$src" "$dst"
    log "Linked $dst -> $src"
}

link_into "$REPO_ROOT/claude/CLAUDE.md"             "$HOME/.claude/CLAUDE.md"
link_into "$REPO_ROOT/claude/settings.json"         "$HOME/.claude/settings.json"
link_into "$REPO_ROOT/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"

# Claude Code skills — symlink each skill directory under ~/.claude/skills/.
if [ -d "$REPO_ROOT/claude/skills" ]; then
    mkdir -p "$HOME/.claude/skills"
    for skill_dir in "$REPO_ROOT/claude/skills"/*/; do
        skill_name="$(basename "$skill_dir")"
        link_into "${skill_dir%/}" "$HOME/.claude/skills/$skill_name"
    done
fi
link_into "$REPO_ROOT/claude-statusline/next_meeting.swift" \
          "$HOME/.config/claude-statusline/next_meeting.swift"

# Karabiner-Elements configuration (custom modifications).
# Karabiner rewrites karabiner.json when settings change via its GUI, so the
# symlink lets those edits flow back to the repo automatically.
link_into "$REPO_ROOT/karabiner/karabiner.json" \
          "$HOME/.config/karabiner/karabiner.json"
link_into "$REPO_ROOT/karabiner/assets/complex_modifications/1768600169.json" \
          "$HOME/.config/karabiner/assets/complex_modifications/1768600169.json"

# Compile the next_meeting EventKit binary used by the statusline.
# swiftc ships with the Xcode Command Line Tools.
meeting_bin="$HOME/.config/claude-statusline/next_meeting"
meeting_src="$HOME/.config/claude-statusline/next_meeting.swift"
if [ ! -x "$meeting_bin" ] || [ "$meeting_src" -nt "$meeting_bin" ]; then
    log "Compiling next_meeting Swift binary..."
    swiftc -O "$meeting_src" -o "$meeting_bin"
else
    log "next_meeting binary is up to date; skipping."
fi

# Per-machine git identity: user.email lives in ~/.gitconfig.local
# (referenced via [include] in the tracked gitconfig).
gitconfig_local="$HOME/.gitconfig.local"
if [ ! -f "$gitconfig_local" ] || ! grep -q '^\s*email\s*=' "$gitconfig_local" 2>/dev/null; then
    printf 'Enter your git email: '
    read -r git_email
    {
        printf '[user]\n'
        printf '\temail = %s\n' "$git_email"
    } > "$gitconfig_local"
    log "Wrote $gitconfig_local"
else
    log "$gitconfig_local already configured; skipping."
fi

# macOS system preferences.
log "Applying macOS system preferences..."
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
defaults write -g WebAutomaticSpellingCorrectionEnabled -bool false
defaults write -g NSAutomaticTextCompletionEnabled -bool false
defaults write -g NSAutomaticCapitalizationEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
# Trackpad: disable "natural" scroll direction (scroll content the classic way).
defaults write -g com.apple.swipescrolldirection -bool false
# Menu bar: never auto-hide.
defaults write NSGlobalDomain _HIHideMenuBar -bool false

# Touch ID for sudo: install pam config that enables pam_tid.so.
# Overrides sudo_local.template (which ships with the auth line commented).
# Requires sudo; will prompt for password if not cached.
pam_src="$REPO_ROOT/pam/sudo_local"
pam_dst="/etc/pam.d/sudo_local"
if [ ! -f "$pam_dst" ] || ! cmp -s "$pam_src" "$pam_dst"; then
    log "Installing $pam_dst for Touch ID (may prompt for sudo password)..."
    sudo install -m 644 -o root -g wheel "$pam_src" "$pam_dst"
else
    log "$pam_dst already up to date; skipping."
fi

# Power management. Requires sudo; will prompt for password if not cached.
log "Configuring display sleep timers (may prompt for sudo password)..."
sudo pmset -b displaysleep 5
sudo pmset -c displaysleep 10

log "Bootstrap complete. Restart your terminal or run: source ~/.zshrc"
log "Remember to run 'gh auth login' to authenticate with GitHub."
