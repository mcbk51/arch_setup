#!/usr/bin/env bash
# Exit on any error, treat unset vars as errors, fail on pipe errors
set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging function with timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

log_info() {
    echo -e "${YELLOW}ℹ️  $*${NC}"
}

log_warning() {
    echo -e "${BLUE}⚠️  $*${NC}"
}

# Countdown prompt function
countdown_prompt() {
    local prompt="$1"
    local default="$2"
    local timeout="${3:-10}"
    local answer=""
    
    echo -n "$prompt"
    
    if read -t "$timeout" -r answer; then
        echo ""
    else
        echo ""
        log_info "Timeout - selecting default: $default"
        answer="$default"
    fi
    
    answer=${answer:-$default}
    
    case $answer in
        [Yy]* ) return 0;;
        [Nn]* ) return 1;;
        * ) 
            case $default in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
            esac
            ;;
    esac
}

# Error handler
trap 'log_error "Setup failed at: $BASH_COMMAND"; exit 1' ERR

# Function to check and run script
run_script() {
    local script_path="$1"
    local script_name="$2"
    
    if [ ! -f "$script_path" ]; then
        log_error "$script_name not found at: $script_path"
        exit 1
    fi
    
    chmod +x "$script_path"
    log_info "Running $script_name..."
    "$script_path"
}

# Main setup process
main() {
    log "Starting full Arch Linux system setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Step 1: Pacman packages
    run_script "./arch-pkg-setup.sh" "package installer"
    log_success "Pacman and AUR apps installed"
    
    # Step 2: Dotfiles setup
    run_script "./dotfiles-stow-setup.sh" "dotfiles configuration"
    log_success "Dotfiles configured"
    
    # Step 3: flatpak packages (flatpaks)
    run_script "./flatpak-pkg-setup.sh" "flatpak package installer"
    log_success "Flatpak apps installed"
    
    # Step 4: Shell setup
    run_script "./zsh-shell-setup.sh" "zsh shell setup"
    log_success "Shell changed to zsh"
    
    # Final summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "All setup steps completed successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Summary:"
    echo "  • Pacman and AUR packages installed"
    echo "  • Dotfiles configured"
    echo "  • Flatpak packages installed"
    echo "  • Shell changed to zsh"
    echo ""
    
    # Reboot prompt
    echo ""
    read -rp "You should reboot the system. Do you want to reboot now? (Y/n): " answer
    answer=${answer:-y}
    
    case $answer in
        [Yy]* )
            log_info "Rebooting system..."
            sudo reboot
            ;;
        [Nn]* )
            log_info "Reboot skipped. Please reboot manually when ready."
            echo "Run 'sudo reboot' to restart your system."
            ;;
        * )
            log_info "Rebooting system..."
            sudo reboot
            ;;
    esac
}

# Run main function
main
