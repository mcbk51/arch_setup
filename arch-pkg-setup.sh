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
        print_info "Timeout - selecting default: $default"
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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root (don't use sudo)"
   exit 1
fi

# Print logo
print_logo() {
    cat << "EOF"
============================================
   Arch Linux System Installer
============================================
EOF
}

clear
print_logo
echo ""

# Source the package configuration
if [ ! -f "packages.conf" ]; then
    print_error "packages.conf not found!"
    exit 1
fi

# shellcheck disable=SC1091
source packages.conf
print_success "Loaded package configuration"
echo ""

# System update
print_info "Updating system..."
if ! sudo pacman -Syu --noconfirm; then
    print_error "System update failed"
    exit 1
fi
print_success "System updated"
echo ""

# Check for AUR helper and install if needed
AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
    print_success "yay is already installed"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
    print_success "paru is already installed"
else
    print_warning "No AUR helper found"
    echo ""
    print_warning "Automatically installing yay in 10 seconds..."
    if countdown_prompt "Do you want to install yay? (Y/n) [10s]: " "y" 10; then
        print_info "Installing yay..."
        
        if ! command -v git &>/dev/null; then
            print_info "Installing required dependencies..."
            sudo pacman -S --needed --noconfirm base-devel git
        fi
        
        TEMP_DIR=$(mktemp -d)
        trap 'rm -rf $TEMP_DIR' EXIT
        
        if git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"; then
            cd "$TEMP_DIR/yay"
            if makepkg -si --noconfirm; then
                AUR_HELPER="yay"
                print_success "yay installed successfully"
            else
                print_error "Failed to build yay"
                exit 1
            fi
            cd - > /dev/null
        else
            print_error "Failed to clone yay repository"
            exit 1
        fi
    else
        print_warning "Continuing without AUR helper (AUR packages will be skipped)"
    fi
fi
echo ""

# Collect all packages from categories
declare -a all_packages=()

# Add packages from each category
for category in SYSTEM_UTILS DEV_TOOLS MAINTENANCE GENERAL_UTILS DESKTOP BROWSER MEDIA GAMING FONTS; do
    # Use indirect expansion to get the array
    declare -n category_packages="$category"
    for pkg in "${category_packages[@]}"; do
        all_packages+=("$pkg")
    done
    unset -n category_packages
done

# Sort packages alphabetically
IFS=$'\n' mapfile -t all_packages < <(printf '%s\n' "${all_packages[@]}" | sort -u)
unset IFS

echo "============================================"
echo "Packages to install:"
echo "============================================"
echo ""
for i in "${!all_packages[@]}"; do
    pkg="${all_packages[$i]}"
    printf "%2d. %s\n" $((i+1)) "$pkg"
done
echo ""
echo "Total packages: ${#all_packages[@]}"
echo "============================================"
echo ""

# Proceed confirmation with countdown
print_warning "Automatically proceeding in 10 seconds..."
if countdown_prompt "Do you want to proceed with installation? (Y/n) [10s]: " "y" 10; then
    echo ""
else
    echo "Installation cancelled."
    exit 0
fi

# Modify list option with countdown
print_warning "Automatically continuing in 10 seconds..."
if countdown_prompt "Do you want to modify the list? (y/N) [10s]: " "n" 10; then
    while true; do
        echo ""
        echo "Current packages:"
        for i in "${!all_packages[@]}"; do
            pkg="${all_packages[$i]}"
            printf "%2d. %s\n" $((i+1)) "$pkg"
        done
        echo ""
        echo "Options:"
        echo "  r <number>  - Remove package by number"
        echo "  a <name>    - Add package by name"
        echo "  d           - Done modifying"
        echo ""
        read -rp "Enter choice: " choice action
        
        case $choice in
            r|R)
                if [[ "$action" =~ ^[0-9]+$ ]] && [ "$action" -ge 1 ] && [ "$action" -le "${#all_packages[@]}" ]; then
                    idx=$((action-1))
                    removed="${all_packages[$idx]}"
                    unset 'all_packages[$idx]'
                    all_packages=("${all_packages[@]}")
                    print_success "Removed: $removed"
                else
                    print_error "Invalid number"
                fi
                ;;
            a|A)
                if [ -n "$action" ]; then
                    all_packages+=("$action")
                    print_success "Added: $action"
                else
                    print_error "Please provide a package name"
                fi
                ;;
            d|D)
                break
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
    done
fi

echo ""
echo "============================================"
echo "Final installation list:"
echo "============================================"
echo ""
print_info "Packages to install (${#all_packages[@]} total):"
for pkg in "${all_packages[@]}"; do
    echo "  • $pkg"
done
echo ""

# Final confirmation with countdown
print_warning "Automatically proceeding in 10 seconds..."
if countdown_prompt "Proceed with installation? (Y/n) [10s]: " "y" 10; then
    echo ""
else
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "============================================"
print_info "Starting installation..."
echo "============================================"
echo ""

# Separate packages into official and AUR
declare -a official_packages=()
declare -a aur_packages=()
declare -a failed_packages=()

for pkg in "${all_packages[@]}"; do
    # Try official repos first
    if pacman -Si "$pkg" &>/dev/null; then
        official_packages+=("$pkg")
    elif [ -n "$AUR_HELPER" ]; then
        # Check if it's an AUR package
        if $AUR_HELPER -Si "$pkg" &>/dev/null; then
            aur_packages+=("$pkg")
        else
            failed_packages+=("$pkg")
        fi
    else
        # No AUR helper, check if it exists in official repos
        failed_packages+=("$pkg")
    fi
done

# Install official packages
if [ ${#official_packages[@]} -gt 0 ]; then
    print_info "Installing official repository packages..."
    for pkg in "${official_packages[@]}"; do
        print_info "Installing: $pkg"
        if sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
            print_success "$pkg installed"
        else
            print_warning "Failed to install: $pkg"
            failed_packages+=("$pkg")
        fi
    done
    echo ""
fi

# Install AUR packages
if [ ${#aur_packages[@]} -gt 0 ] && [ -n "$AUR_HELPER" ]; then
    print_info "Installing AUR packages..."
    for pkg in "${aur_packages[@]}"; do
        print_info "Installing: $pkg"
        if $AUR_HELPER -S --needed --noconfirm "$pkg" &>/dev/null; then
            print_success "$pkg installed"
        else
            print_warning "Failed to install: $pkg"
            failed_packages+=("$pkg")
        fi
    done
    echo ""
fi

# Report failures
if [ ${#failed_packages[@]} -gt 0 ]; then
    print_warning "Some packages were not found or failed to install:"
    for pkg in "${failed_packages[@]}"; do
        echo "  • $pkg"
    done
    echo ""
fi

# Enable services
if [ ${#SERVICES[@]} -gt 0 ]; then
    echo "============================================"
    print_info "Configuring services..."
    echo "============================================"
    echo ""
    
    for service in "${SERVICES[@]}"; do
        if ! systemctl is-enabled "$service" &> /dev/null; then
            print_info "Enabling $service..."
            if sudo systemctl enable "$service" &>/dev/null; then
                print_success "$service enabled"
            else
                print_warning "Failed to enable $service"
            fi
        else
            print_info "$service is already enabled"
        fi
    done
    echo ""
fi

echo "============================================"
print_success "Installation complete!"
echo "============================================"
echo ""

# Post-installation suggestions
print_info "Post-installation suggestions:"
echo "  • Reboot your system: sudo reboot"
echo "  • Set zsh as default shell: chsh -s \$(which zsh)"
echo "  • Configure your dotfiles with stow"
echo ""
