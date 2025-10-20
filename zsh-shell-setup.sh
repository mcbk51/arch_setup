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

echo "============================================"
echo "  ZSH Setup Script"
echo "============================================"
echo ""

# Check if zsh is already the current shell
if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
    print_success "zsh is already your default shell"
    exit 0
fi

# Check if zsh is installed
if ! command -v zsh &> /dev/null; then
    print_warning "zsh is not installed"
    echo ""
    print_warning "Automatically installing zsh in 10 seconds..."
    if countdown_prompt "Do you want to install zsh? (Y/n) [10s]: " "y" 10; then
        print_info "Installing zsh..."
        if sudo pacman -S zsh --noconfirm; then
            # Verify installation succeeded
            if ! command -v zsh &> /dev/null; then
                print_error "zsh installation failed"
                exit 1
            fi
            print_success "zsh installed"
        else
            print_error "Failed to install zsh"
            exit 1
        fi
    else
        print_error "zsh is required for this script"
        exit 1
    fi
else
    print_success "zsh is already installed"
fi

echo ""

# Confirm shell change
print_warning "Automatically proceeding in 10 seconds..."
if countdown_prompt "Do you want to switch your default shell to zsh? (Y/n) [10s]: " "y" 10; then
    print_info "Switching shell to zsh..."
    if chsh -s /bin/zsh; then
        echo ""
        print_success "Shell changed to zsh"
        echo ""
        print_info "Please log out and log back in for changes to take effect"
    else
        print_error "Failed to change shell"
        exit 1
    fi
else
    print_info "Shell change cancelled"
    exit 0
fi

echo ""
