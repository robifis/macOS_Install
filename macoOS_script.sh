#!/usr/bin/env bash
# =============================================================================
# Enhanced System Maintenance & Setup Script
#
# This script performs system maintenance and configuration including:
# - Ensuring a Bash version >= 4 is running (updating on macOS if needed)
# - Installing Homebrew (macOS) or using apt/pacman for Linux distros.
# - Checking and installing terminal emulators (only if none is detected).
# - Configuring terminal themes with a numbered menu.
# - Creating a minimal config file.
# - Installing JetBrains Nerd Font Mono if missing.
# - Updating system packages (skipping reinstallations).
# - Installing and configuring Neovim with Packer.
# - Installing and configuring zsh with zinit and recommended plugins.
# - Checking git installation and SSH key for GitHub.
# - Backing up configuration files to a GitHub repository.
# - Clearing old files from the Downloads folder.
#
# Improvements include robust error handling, modular functions, enhanced logging,
# dry-run mode, and interactive numbered choices.
# =============================================================================

# Enable strict error handling and trap signals.
set -euo pipefail
trap 'echo "Script interrupted or an error occurred. Exiting." >&2; exit 1' SIGINT SIGTERM

# -------------------------------
# Function: update_bash_if_needed
# -------------------------------
# Checks if the current Bash version is at least 4.
# On macOS, if not, it installs the newer Bash and re-executes the script.
update_bash_if_needed() {
    if (( ${BASH_VERSINFO[0]} < 4 )); then
        echo "Current Bash version is ${BASH_VERSINFO[0]}. Updating Bash to version 4 or higher..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command -v brew &>/dev/null; then
                echo "Homebrew is required to update Bash on macOS. Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install bash
            if [ -f /opt/homebrew/bin/bash ]; then
                NEW_BASH="/opt/homebrew/bin/bash"
            else
                NEW_BASH="/usr/local/bin/bash"
            fi
            echo "Re-executing script with updated Bash ($NEW_BASH)..."
            exec "$NEW_BASH" "$0" "$@"
        else
            echo "Please update your Bash version to 4 or higher."
            exit 1
        fi
    fi
}
update_bash_if_needed

# Global variables
LOG_DIR="$HOME/LOGS"
INSTALLED_APPS_LOG="$LOG_DIR/installed_apps.txt"
CONFIG_BACKUP_DIR="$HOME/config_backup"
GITHUB_REPO="git@github.com:robifis/macOS_Install.git"
DRY_RUN=${DRY_RUN:-false}  # Set DRY_RUN=true for testing

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/script.log"

# -------------------------------
# Function: log_msg
# -------------------------------
# Logs messages with a timestamp and level.
log_msg() {
    local level="$1"
    shift
    local msg="$*"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [$level] $msg" | tee -a "$LOG_FILE"
}

log_msg INFO "Starting enhanced system maintenance script"

# -------------------------------
# Function: detect_os
# -------------------------------
# Detects the current operating system and sets OS_TYPE and PKG_MANAGER.
detect_os() {
    log_msg INFO "Detecting OS and package manager..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        PKG_MANAGER="brew"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS_TYPE="$ID"
            if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
                PKG_MANAGER="apt"
            elif [[ "$ID" == "arch" || "$ID" == "manjaro" ]]; then
                if command -v yay >/dev/null 2>&1; then
                    PKG_MANAGER="yay"
                else
                    PKG_MANAGER="pacman"
                fi
            else
                PKG_MANAGER="apt"
            fi
        else
            log_msg ERROR "Cannot detect Linux distribution."
            exit 1
        fi
    else
        log_msg ERROR "Unsupported OS: $OSTYPE"
        exit 1
    fi
    log_msg INFO "Detected OS: $OS_TYPE, Package Manager: $PKG_MANAGER"
}
detect_os

# -------------------------------
# Platform-specific package installation functions
# -------------------------------
install_package_macos() {
    local pkg="$1"
    # Check if it's a cask package.
    if brew list --cask "$pkg" &>/dev/null || brew list "$pkg" &>/dev/null; then
        log_msg INFO "$pkg is already installed on macOS. Skipping installation."
    else
        log_msg INFO "Installing $pkg on macOS..."
        if ! $DRY_RUN; then
            if [[ "$pkg" == "font-jetbrains-mono-nerd-font" ]]; then
                brew install --cask "$pkg"
            else
                brew install "$pkg" || brew install --cask "$pkg"
            fi
        else
            log_msg INFO "[DRY-RUN] Would install $pkg via Homebrew."
        fi
    fi
}

install_package_debian() {
    local pkg="$1"
    # For apt, we check with dpkg -l.
    if dpkg -l | grep -qw "$pkg"; then
        log_msg INFO "$pkg is already installed on Debian/Ubuntu. Skipping installation."
    else
        log_msg INFO "Installing $pkg on Debian/Ubuntu..."
        if ! $DRY_RUN; then
            sudo apt update && sudo apt install -y "$pkg"
        else
            log_msg INFO "[DRY-RUN] Would install $pkg via apt."
        fi
    fi
}

install_package_arch() {
    local pkg="$1"
    # For Arch, check with pacman -Q.
    if pacman -Q "$pkg" &>/dev/null; then
        log_msg INFO "$pkg is already installed on Arch. Skipping installation."
    else
        log_msg INFO "Installing $pkg on Arch-based system..."
        if ! $DRY_RUN; then
            if [[ "$PKG_MANAGER" == "yay" ]]; then
                yay -S --noconfirm "$pkg"
            else
                sudo pacman -Syu --noconfirm "$pkg"
            fi
        else
            log_msg INFO "[DRY-RUN] Would install $pkg via $PKG_MANAGER."
        fi
    fi
}

install_package() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        brew) install_package_macos "$pkg" ;;
        apt) install_package_debian "$pkg" ;;
        pacman|yay) install_package_arch "$pkg" ;;
        *) log_msg ERROR "No known package manager for installation." ;;
    esac
}

# -------------------------------
# Function: install_homebrew
# -------------------------------
# Checks if Homebrew is installed on macOS and installs it if missing.
install_homebrew() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        log_msg INFO "Checking for Homebrew..."
        if ! command -v brew >/dev/null 2>&1; then
            log_msg INFO "Homebrew not found. Installing Homebrew..."
            if ! $DRY_RUN; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            else
                log_msg INFO "[DRY-RUN] Would install Homebrew."
            fi
        else
            log_msg INFO "Homebrew is already installed."
        fi
    fi
}
install_homebrew

# -------------------------------
# Function: check_terminal_emulator
# -------------------------------
# Checks for specified terminal emulators. If one is detected, installation is skipped.
check_terminal_emulator() {
    log_msg INFO "Checking for terminal emulators..."
    local found=0
    for term in ghostty alacritty "iTerm2" Hyper; do
        if command -v "${term,,}" >/dev/null 2>&1 || [ -d "/Applications/${term}*.app" ]; then
            log_msg INFO "$term is already installed. Skipping terminal installation."
            found=1
            break
        fi
    done

    if [ $found -eq 0 ]; then
        log_msg INFO "No known terminal emulator found. Please choose one to install:"
        PS3="Enter the number corresponding to your choice: "
        options=("ghostty" "alacritty" "iTerm2" "Hyper")
        select opt in "${options[@]}"; do
            if [[ " ${options[*]} " =~ " ${opt} " ]]; then
                log_msg INFO "User selected $opt. Installing..."
                install_package "$opt"
                break
            else
                log_msg ERROR "Invalid option. Try again."
            fi
        done
    fi
}
check_terminal_emulator

# -------------------------------
# Function: setup_terminal_theme
# -------------------------------
# Prompts user for terminal theme settings using a numbered list and creates a minimal config.
setup_terminal_theme() {
    log_msg INFO "Configuring terminal theme..."
    echo "Select a terminal theme:"
    PS3="Enter the number corresponding to your choice: "
    options=("Gruvbox" "Solarized" "OneDark" "Custom")
    select choice in "${options[@]}"; do
        case "$REPLY" in
            1) TERM_THEME="gruvbox"; break;;
            2) TERM_THEME="solarized"; break;;
            3) TERM_THEME="onedark"; break;;
            4) read -p "Enter custom theme name: " TERM_THEME; break;;
            *) echo "Invalid choice. Try again.";;
        esac
    done

    read -p "Select a prompt style (e.g., powerlevel10k, oh-my-zsh): " PROMPT_STYLE

    CONFIG_FILE="$HOME/terminal_config.conf"
    cat > "$CONFIG_FILE" <<EOF
# Minimal Terminal Configuration
# Theme: $TERM_THEME
# Prompt Style: $PROMPT_STYLE

# Set custom background, font, and colors based on $TERM_THEME
BACKGROUND_COLOR="#282828"  # Example for gruvbox
FONT="JetBrainsMono Nerd Font Mono"
# Function to switch themes dynamically:
switch_theme() {
    echo "Switching theme to \$1..."
    # Insert dynamic theme switching logic here.
}
EOF
    log_msg INFO "Terminal configuration created at $CONFIG_FILE"
}
setup_terminal_theme

# -------------------------------
# Function: install_nerd_fonts
# -------------------------------
# Checks if JetBrains Nerd Font Mono is installed and installs it if missing.
install_nerd_fonts() {
    log_msg INFO "Checking for JetBrains Nerd Font Mono..."
    FONT_PATH_MAC="$HOME/Library/Fonts/JetBrainsMono Nerd Font Mono.ttf"
    FONT_PATH_LINUX="/usr/share/fonts/truetype/jetbrains/JetBrainsMonoNL-Regular.ttf"
    if [[ "$OS_TYPE" == "macos" ]]; then
        if brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
            log_msg INFO "JetBrains Nerd Font Mono is already installed via Homebrew cask."
        elif [ ! -f "$FONT_PATH_MAC" ]; then
            log_msg INFO "Installing JetBrains Nerd Font Mono on macOS..."
            install_package "font-jetbrains-mono-nerd-font"
        else
            log_msg INFO "JetBrains Nerd Font Mono is already installed."
        fi
    else
        if [ ! -f "$FONT_PATH_LINUX" ]; then
            log_msg INFO "Installing JetBrains Nerd Font Mono on Linux..."
            install_package "ttf-jetbrains-mono" || install_package "fonts-jetbrains-mono"
        else
            log_msg INFO "JetBrains Nerd Font Mono is already installed on Linux."
        fi
    fi
}
install_nerd_fonts

# -------------------------------
# Function: update_system_apps
# -------------------------------
# Updates installed packages.
update_system_apps() {
    log_msg INFO "Updating installed apps..."
    case "$PKG_MANAGER" in
        brew)
            if ! $DRY_RUN; then
                brew update && brew upgrade || log_msg ERROR "brew upgrade encountered issues. Skipping upgrade errors."
            else
                log_msg INFO "[DRY-RUN] Would update Homebrew packages."
            fi
            ;;
        apt)
            if ! $DRY_RUN; then
                sudo apt update && sudo apt upgrade -y
            else
                log_msg INFO "[DRY-RUN] Would update apt packages."
            fi
            ;;
        pacman|yay)
            if ! $DRY_RUN; then
                if [[ "$PKG_MANAGER" == "yay" ]]; then
                    yay -Syu --noconfirm
                else
                    sudo pacman -Syu --noconfirm
                fi
            else
                log_msg INFO "[DRY-RUN] Would update packages via $PKG_MANAGER."
            fi
            ;;
    esac
}
update_system_apps

# -------------------------------
# Function: log_installed_apps
# -------------------------------
# Logs a list of installed apps/packages.
log_installed_apps() {
    log_msg INFO "Logging installed applications..."
    case "$PKG_MANAGER" in
        brew)
            brew list > "$INSTALLED_APPS_LOG"
            ;;
        apt)
            dpkg --get-selections > "$INSTALLED_APPS_LOG"
            ;;
        pacman)
            pacman -Q > "$INSTALLED_APPS_LOG"
            ;;
        yay)
            yay -Q > "$INSTALLED_APPS_LOG"
            ;;
    esac
    log_msg INFO "Installed apps logged to $INSTALLED_APPS_LOG"
}
log_installed_apps

# -------------------------------
# Function: install_nvim_and_configure
# -------------------------------
# Installs Neovim if missing and runs an interactive configuration guide.
install_nvim_and_configure() {
    log_msg INFO "Checking for Neovim..."
    if ! command -v nvim >/dev/null 2>&1; then
        log_msg INFO "Neovim not found. Installing..."
        install_package "neovim"
        log_msg INFO "Neovim installed. Starting interactive configuration guide..."
        read -p "Enter preferred nvim theme (e.g., gruvbox, onedark): " NVIM_THEME
        read -p "Enter desired plugins (comma separated, e.g., nvim-tree/telescope): " NVIM_PLUGINS
        read -p "Show line numbers? (yes/no): " SHOW_LNUM

        NVIM_CONFIG_DIR="$HOME/.config/nvim"
        mkdir -p "$NVIM_CONFIG_DIR"
        INIT_FILE="$NVIM_CONFIG_DIR/init.lua"

        cat > "$INIT_FILE" <<EOF
-- Minimal Neovim configuration
vim.o.number = $( [[ "${SHOW_LNUM,,}" == "yes" ]] && echo "true" || echo "false" )
vim.cmd("colorscheme $NVIM_THEME")

-- Bootstrap Packer
vim.cmd [[packadd packer.nvim]]
require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'
  -- Additional plugins:
EOF

        IFS=',' read -ra plugins <<< "$NVIM_PLUGINS"
        for plugin in "${plugins[@]}"; do
            plugin_trimmed=$(echo "$plugin" | xargs)
            if [ -n "$plugin_trimmed" ]; then
                echo "  use '$plugin_trimmed'" >> "$INIT_FILE"
            fi
        done

        cat >> "$INIT_FILE" <<EOF
end)
EOF
        log_msg INFO "Neovim configuration created at $INIT_FILE"
    else
        log_msg INFO "Neovim is already installed."
    fi
}
install_nvim_and_configure

# -------------------------------
# Function: install_and_configure_zsh
# -------------------------------
# Installs zsh (if needed), zinit, and configures recommended plugins.
install_and_configure_zsh() {
    log_msg INFO "Checking for zsh..."
    if ! command -v zsh >/dev/null 2>&1; then
        log_msg INFO "zsh not found. Installing..."
        install_package "zsh"
    else
        log_msg INFO "zsh is already installed."
    fi

    if [ ! -d "$HOME/.zinit" ]; then
        log_msg INFO "Installing zinit..."
        if ! $DRY_RUN; then
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/doc/install.sh)"
        else
            log_msg INFO "[DRY-RUN] Would install zinit."
        fi
    fi

    echo "Recommended zsh plugins:"
    echo " 1. zsh-syntax-highlighting"
    echo " 2. zsh-autosuggestions"
    echo " 3. zsh-completions"
    echo " 4. zsh-vim-mode (for vim-like behavior)"
    read -p "Enter plugin numbers separated by commas (e.g., 1,2,4): " ZSH_PLUGIN_SELECTION

    ZSHRC_FILE="$HOME/.zshrc"
    [ -f "$ZSHRC_FILE" ] && cp "$ZSHRC_FILE" "$ZSHRC_FILE.bak"
    cat > "$ZSHRC_FILE" <<EOF
# Basic zsh configuration
export ZINIT_HOME="\$HOME/.zinit"
source "\$ZINIT_HOME/zinit.git/zinit.zsh"
EOF

    IFS=',' read -ra selected_plugins <<< "$ZSH_PLUGIN_SELECTION"
    for num in "${selected_plugins[@]}"; do
        num=$(echo "$num" | xargs)
        case "$num" in
            1) plugin="zsh-users/zsh-syntax-highlighting" ;;
            2) plugin="zsh-users/zsh-autosuggestions" ;;
            3) plugin="zsh-users/zsh-completions" ;;
            4) plugin="jeffreytse/zsh-vim-mode" ;;
            *) plugin="" ;;
        esac
        if [ -n "$plugin" ]; then
            echo "zinit light $plugin" >> "$ZSHRC_FILE"
        fi
    done

    if [[ "$PROMPT_STYLE" =~ powerlevel10k ]]; then
        echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> "$ZSHRC_FILE"
    elif [[ "$PROMPT_STYLE" =~ oh-my-zsh ]]; then
        echo 'export ZSH="$HOME/.oh-my-zsh"' >> "$ZSHRC_FILE"
        echo 'ZSH_THEME="robbyrussell"' >> "$ZSHRC_FILE"
        echo 'source $ZSH/oh-my-zsh.sh' >> "$ZSHRC_FILE"
    fi

    log_msg INFO "zsh configuration written to $ZSHRC_FILE"
}
install_and_configure_zsh

# -------------------------------
# Function: check_git_and_ssh_key
# -------------------------------
# Installs git if missing and ensures an SSH key exists for GitHub.
check_git_and_ssh_key() {
    log_msg INFO "Checking for git..."
    if ! command -v git >/dev/null 2>&1; then
        log_msg INFO "git not found. Installing..."
        install_package "git"
    else
        log_msg INFO "git is already installed."
    fi

    if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
        log_msg INFO "No SSH key found. Generating a new SSH key for GitHub..."
        mkdir -p "$HOME/.ssh"
        if ! $DRY_RUN; then
            ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f "$HOME/.ssh/id_rsa" -N ""
        else
            log_msg INFO "[DRY-RUN] Would generate an SSH key."
        fi
        log_msg INFO "SSH key generated. Please add the following key to GitHub:"
        cat "$HOME/.ssh/id_rsa.pub" || log_msg ERROR "Could not display SSH key."
        echo "Visit: https://github.com/settings/keys"
    else
        log_msg INFO "SSH key already exists."
    fi
}
check_git_and_ssh_key

# -------------------------------
# Function: backup_configs_to_github
# -------------------------------
# Backs up configuration files to the specified GitHub repository.
backup_configs_to_github() {
    log_msg INFO "Backing up configuration files to GitHub..."
    mkdir -p "$CONFIG_BACKUP_DIR"
    cp "$0" "$CONFIG_BACKUP_DIR/"  # Backup this script
    [ -f "$HOME/terminal_config.conf" ] && cp "$HOME/terminal_config.conf" "$CONFIG_BACKUP_DIR/"
    [ -f "$HOME/.config/nvim/init.lua" ] && cp "$HOME/.config/nvim/init.lua" "$CONFIG_BACKUP_DIR/"
    [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$CONFIG_BACKUP_DIR/"

    cd "$CONFIG_BACKUP_DIR" || { log_msg ERROR "Failed to change directory to $CONFIG_BACKUP_DIR"; exit 1; }
    if [ ! -d ".git" ]; then
        git init
        git remote add origin "$GITHUB_REPO"
    fi
    git add .
    git commit -m "Backup configs on $(date)" || log_msg INFO "Nothing to commit."
    if ! $DRY_RUN; then
        git push -u origin master || log_msg ERROR "Git push failed. Please check your remote repository settings."
    else
        log_msg INFO "[DRY-RUN] Would push backup to $GITHUB_REPO."
    fi
    log_msg INFO "Backup complete."
}
backup_configs_to_github

# -------------------------------
# Function: clear_old_downloads
# -------------------------------
# Deletes files from the Downloads folder older than 7 days.
clear_old_downloads() {
    log_msg INFO "Clearing files older than 7 days from Downloads..."
    if ! $DRY_RUN; then
        find "$HOME/Downloads" -type f -mtime +7 -delete
    else
        log_msg INFO "[DRY-RUN] Would clear old files from Downloads."
    fi
    log_msg INFO "Downloads cleanup complete."
}
clear_old_downloads

# -------------------------------
# Function: create_readme
# -------------------------------
# Creates a README.md for the backup repository.
create_readme() {
    log_msg INFO "Creating README.md for backup repository..."
    README_FILE="$CONFIG_BACKUP_DIR/README.md"
    cat > "$README_FILE" <<EOF
# System Maintenance & Configurations Backup

This repository contains the following configuration files:
- **Script:** The system maintenance and installation script.
- **terminal_config.conf:** Minimal configuration for terminal themes and dynamic switching.
- **nvim/init.lua:** Minimal Neovim configuration using Packer with custom themes, plugins, and settings.
- **.zshrc:** zsh configuration with plugins installed via zinit.

## How to Use
- Run the script on your system. It auto-detects your OS and installs/configures required packages.
- Logs are stored in \`~/LOGS/script.log\`.

## Backup Process
- This repository is updated each time the script runs to back up your configurations.
EOF
    log_msg INFO "README.md created at $README_FILE"
}
create_readme

log_msg INFO "System maintenance script completed. Check $LOG_FILE for details."

