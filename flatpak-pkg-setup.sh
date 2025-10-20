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

echo "============================================"
echo "  Flatpak Application Installer"
echo "============================================"
echo ""

# Check if flatpak is installed
if ! command -v flatpak &>/dev/null; then
    print_error "Flatpak is not installed!"
    echo ""
    print_warning "Automatically installing flatpak in 10 seconds..."
    if countdown_prompt "Do you want to install flatpak? (Y/n) [10s]: " "y" 10; then
        print_info "Installing flatpak..."
        if sudo pacman -S --needed --noconfirm flatpak; then
            print_success "Flatpak installed successfully"
        else
            print_error "Failed to install flatpak"
            exit 1
        fi
    else
        print_error "Flatpak is required to continue"
        exit 1
    fi
fi

print_success "Flatpak is installed"
echo ""

# Source the flatpak configuration
if [ ! -f "flatpaks.conf" ]; then
    print_error "flatpaks.conf not found!"
    exit 1
fi

# shellcheck disable=SC1091
source flatpaks.conf
print_success "Loaded flatpak configuration"
echo ""

# Collect all flatpaks from categories
declare -a all_flatpaks=()

# Add flatpaks from each category
for category in GENERAL_UTILS BROWSER MEDIA; do
    # Use indirect expansion to get the array
    declare -n category_flatpaks="$category"
    for pak in "${category_flatpaks[@]}"; do
        all_flatpaks+=("$pak")
    done
    unset -n category_flatpaks
done

# Check if flatpaks array is empty
if [ ${#all_flatpaks[@]} -eq 0 ]; then
    print_warning "No flatpaks specified in configuration"
    exit 0
fi

# Setup Flathub repository if not already added
print_info "Setting up Flathub repository..."
if ! flatpak remotes | grep -q "flathub"; then
    if flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
        print_success "Flathub repository added"
    else
        print_error "Failed to add Flathub repository"
        exit 1
    fi
else
    print_success "Flathub repository already configured"
fi
echo ""

# Display flatpaks to install
declare -a flatpaks_to_install=("${all_flatpaks[@]}")

echo "============================================"
echo "Flatpaks to install:"
echo "============================================"
echo ""
for i in "${!flatpaks_to_install[@]}"; do
    printf "%2d. %s\n" $((i+1)) "${flatpaks_to_install[$i]}"
done
echo ""
echo "Total flatpaks: ${#flatpaks_to_install[@]}"
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
        echo "Current flatpaks:"
        for i in "${!flatpaks_to_install[@]}"; do
            printf "%2d. %s\n" $((i+1)) "${flatpaks_to_install[$i]}"
        done
        echo ""
        echo "Options:"
        echo "  r <number>  - Remove flatpak by number"
        echo "  a <name>    - Add flatpak by name"
        echo "  d           - Done modifying"
        echo ""
        read -rp "Enter choice: " choice action
        
        case $choice in
            r|R)
                if [[ "$action" =~ ^[0-9]+$ ]] && [ "$action" -ge 1 ] && [ "$action" -le "${#flatpaks_to_install[@]}" ]; then
                    idx=$((action-1))
                    removed="${flatpaks_to_install[$idx]}"
                    unset 'flatpaks_to_install[$idx]'
                    flatpaks_to_install=("${flatpaks_to_install[@]}")
                    print_success "Removed: $removed"
                else
                    print_error "Invalid number"
                fi
                ;;
            a|A)
                if [ -n "$action" ]; then
                    flatpaks_to_install+=("$action")
                    print_success "Added: $action"
                else
                    print_error "Please provide a flatpak name"
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
print_info "Flatpaks to install (${#flatpaks_to_install[@]} total):"
for pak in "${flatpaks_to_install[@]}"; do
    echo "  • $pak"
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
print_info "Starting flatpak installation..."
echo "============================================"
echo ""

# Install flatpaks
already_installed=()
newly_installed=()
failed_installs=()

for pak in "${flatpaks_to_install[@]}"; do
    if flatpak list | grep -qi "$pak"; then
        print_info "Already installed: $pak"
        already_installed+=("$pak")
    else
        print_info "Installing: $pak"
        if flatpak install --noninteractive flathub "$pak" &>/dev/null; then
            print_success "$pak installed"
            newly_installed+=("$pak")
        else
            print_warning "Failed to install: $pak"
            failed_installs+=("$pak")
        fi
    fi
done

echo ""
echo "============================================"
print_success "Installation Summary"
echo "============================================"
echo ""

if [ ${#newly_installed[@]} -gt 0 ]; then
    print_success "Newly installed (${#newly_installed[@]}):"
    for pak in "${newly_installed[@]}"; do
        echo "  • $pak"
    done
    echo ""
fi

if [ ${#already_installed[@]} -gt 0 ]; then
    print_info "Already installed (${#already_installed[@]}):"
    for pak in "${already_installed[@]}"; do
        echo "  • $pak"
    done
    echo ""
fi

if [ ${#failed_installs[@]} -gt 0 ]; then
    print_warning "Failed to install (${#failed_installs[@]}):"
    for pak in "${failed_installs[@]}"; do
        echo "  • $pak"
    done
    echo ""
fi

echo "============================================"
print_success "Flatpak installation complete!"
echo "============================================"
echo ""
