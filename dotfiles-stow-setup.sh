#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Countdown prompt function
# Usage: countdown_prompt "prompt text" "default" timeout
# Returns: 0 for yes, 1 for no
countdown_prompt() {
    local prompt="$1"
    local default="$2"
    local timeout="${3:-10}"
    local answer=""
    
    echo -n "$prompt"
    
    # Read with timeout
    if read -t "$timeout" -r answer; then
        # User provided input
        echo ""
    else
        # Timeout occurred
        echo ""
        print_info "Timeout - selecting default: $default"
        answer="$default"
    fi
    
    # Set default if empty
    answer=${answer:-$default}
    
    case $answer in
        [Yy]* ) return 0;;
        [Nn]* ) return 1;;
        * ) 
            # Invalid input, use default
            case $default in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
            esac
            ;;
    esac
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root (don't use sudo)"
   exit 1
fi

# Configuration
DOTFILES_REPO="https://github.com/mcbk51/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backups"

# Config directories to backup
declare -a config_dirs=(
    "$HOME/.config/fastfetch"
    "$HOME/.config/ghostty"
    "$HOME/.config/hyde"
    "$HOME/.config/hypr"
    "$HOME/.config/nvim"
    "$HOME/.config/starship"
    "$HOME/.config/tmux"
    "$HOME/.config/waybar"
    "$HOME/.config/yazi"
    "$HOME/.config/zsh"
)

# Function to back up existing configs
backup_configs() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/${timestamp}"
    local backed_up=false
    
    echo ""
    print_info "Checking for existing configurations..."
    
    for path in "${config_dirs[@]}"; do
        if [[ -e "$path" ]] && [[ ! -L "$path" ]]; then
            if [[ "$backed_up" == false ]]; then
                mkdir -p "$backup_path"
                backed_up=true
            fi
            
            local relative_path="${path#"$HOME"/}"
            
            print_warning "Backing up: $relative_path"
            
            # Create parent directory structure in backup
            mkdir -p "$backup_path/$(dirname "$relative_path")"
            mv "$path" "$backup_path/$relative_path"
        elif [[ -L "$path" ]]; then
            print_info "Skipping symlink: $(basename "$path")"
        fi
    done
    
    if [[ "$backed_up" == true ]]; then
        print_success "Backups saved to: $backup_path"
    else
        print_success "No existing configurations found to backup"
    fi
}

# Function to check for conflicting files
check_conflicts() {
    local conflicts=()
    
    for path in "${config_dirs[@]}"; do
        if [[ -e "$path" ]] && [[ ! -L "$path" ]]; then
            conflicts+=("$path")
        fi
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo ""
        print_warning "Found ${#conflicts[@]} existing configuration(s):"
        for conflict in "${conflicts[@]}"; do
            echo "  • ${conflict#"$HOME"/}"
        done
        return 0
    fi
    return 1
}

echo "============================================"
echo "  Dotfiles Setup Script"
echo "============================================"
echo ""

# Check if Git is installed
if ! command -v git &>/dev/null; then
    print_error "Git is not installed. Please install it first:"
    echo "  sudo pacman -S git"
    exit 1
fi

# Check if Stow is installed, offer to install if not
if ! command -v stow &>/dev/null; then
    print_warning "GNU Stow is not installed"
    echo ""
    print_warning "Automatically installing GNU Stow in 10 seconds..."
    if countdown_prompt "Do you want to install GNU Stow? (Y/n) [10s]: " "y" 10; then
        print_info "Installing GNU Stow..."
        if sudo pacman -S --needed --noconfirm stow; then
            print_success "GNU Stow installed"
        else
            print_error "Failed to install GNU Stow"
            exit 1
        fi
    else
        print_error "GNU Stow is required for this script"
        exit 1
    fi
else
    print_success "GNU Stow is already installed"
fi

echo ""

# Clone or update dotfiles repository
if [[ -d "$DOTFILES_DIR" ]]; then
    print_info "Dotfiles directory already exists"
    echo ""
    print_warning "Automatically updating in 10 seconds..."
    if countdown_prompt "Do you want to update it? (Y/n) [10s]: " "y" 10; then
        print_info "Updating dotfiles repository..."
        cd "$DOTFILES_DIR"
        if git pull; then
            print_success "Repository updated"
        else
            print_error "Failed to update repository"
            exit 1
        fi
    else
        print_info "Using existing repository"
    fi
else
    print_info "Cloning dotfiles repository..."
    if git clone "$DOTFILES_REPO" "$DOTFILES_DIR"; then
        print_success "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        exit 1
    fi
fi

echo ""

# Check for conflicts and offer to backup
if check_conflicts; then
    echo ""
    print_warning "Automatically backing up in 10 seconds..."
    if countdown_prompt "Do you want to backup existing configurations? (Y/n) [10s]: " "y" 10; then
        backup_configs
    else
        print_warning "Existing configurations will be overwritten!"
        print_warning "Automatically cancelling in 10 seconds..."
        if countdown_prompt "Are you sure you want to continue? (y/N) [10s]: " "n" 10; then
            print_warning "Proceeding without backup..."
        else
            print_info "Installation cancelled"
            exit 0
        fi
    fi
fi

echo ""
echo "============================================"
print_info "Ready to apply dotfiles with GNU Stow"
echo "============================================"
echo ""
print_info "This will create symlinks from $DOTFILES_DIR to your home directory"
echo ""

# Final confirmation
print_warning "Automatically proceeding in 10 seconds..."
if countdown_prompt "Do you want to proceed? (Y/n) [10s]: " "y" 10; then
    echo ""
else
    print_info "Installation cancelled"
    exit 0
fi

print_info "Applying dotfiles..."

# Apply dotfiles with stow
cd "$DOTFILES_DIR"
if stow --restow .; then
    echo ""
    print_success "Dotfiles configured successfully!"
else
    print_error "Failed to apply dotfiles with Stow"
    echo ""
    print_info "You may need to manually remove conflicting files"
    exit 1
fi

echo ""
echo "============================================"
print_success "Setup Complete!"
echo "============================================"
echo ""
print_info "Next steps:"
echo "  • Restart your shell or run: source ~/.zshrc"
echo "  • Check symlinks with: ls -la ~/.config"
echo "  • Your backups are in: $BACKUP_DIR"
echo ""
