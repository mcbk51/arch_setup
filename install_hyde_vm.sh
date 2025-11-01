#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info "This script requires sudo privileges for package installation"
sudo -v

# Installing HyDE Hyprland
print_info "Setting up HyDE"
# Download and run (will auto-detect missing packages)
if curl -L https://raw.githubusercontent.com/HyDE-Project/HyDE/main/Scripts/hydevm/hydevm.sh -o hydevm && chmod +x hydevm && ./hydevm; then 
    print_info "=== HyDE Installation Completed ==="
else
    print_warn "HyDE installation encountered issues, check logs"
fi
