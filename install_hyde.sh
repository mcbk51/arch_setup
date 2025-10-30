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

# Keep sudo alive in background (updates timestamp every 60 seconds)
keep_sudo_alive() {
while true; do
        sudo -n true
        sleep 60
    done 2>/dev/null
}
keep_sudo_alive &
SUDO_PID=$!

# Cleanup function
cleanup() {
    kill $SUDO_PID 2>/dev/null || true
}
trap cleanup EXIT

# Installing HyDE Hyprland
print_info "Setting up HyDE"

if git clone --depth 1 https://github.com/HyDE-Project/HyDE ~/HyDE && cd ~/HyDE/Scripts && ./install.sh; then
    print_info "=== HyDE Installation Completed ==="
else
    print_warn "HyDE installation encountered issues, check logs"
fi
