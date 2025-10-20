# Arch Linux System Setup

A comprehensive, interactive Arch Linux system setup automation tool with support for official repositories, AUR packages, Flatpak applications, dotfiles management, and shell configuration.

## Features

- 🎯 **Interactive Installation** - Countdown timers and manual package selection
- 📦 **Multi-Source Support** - Official repos, AUR, and Flatpak
- ⚙️ **Categorized Packages** - Organized by function (dev tools, utilities, media, etc.)
- 🔧 **Dotfiles Management** - Automated stow-based configuration
- 🐚 **Shell Setup** - Automatic zsh configuration
- ✅ **Service Management** - Auto-enable system services
- 🛡️ **Error Handling** - Graceful failure handling and reporting

## Project Structure

```
.
├── dev_run.sh                 # Main orchestrator script
├── arch-pkg-setup.sh          # Pacman/AUR package installer
├── dotfiles-stow-setup.sh     # Dotfiles configuration (user-provided)
├── flatpak-pkg-setup.sh       # Flatpak application installer
├── zsh-shell-setup.sh         # Shell setup script (user-provided)
├── packages.conf              # Package configuration
└── flatpaks.conf              # Flatpak configuration
```

## Prerequisites

- Fresh or existing Arch Linux installation
- Internet connection
- Sudo privileges

## Quick Start

1. **Clone or download this repository**
   ```bash
   git clone <your-repo-url>
   cd arch-setup
   ```

2. **Configure your packages**
   
   Edit `packages.conf` to customize packages:
   ```bash
   vim packages.conf
   ```

3. **Configure Flatpak applications**
   
   Edit `flatpaks.conf` to add/remove Flatpak apps:
   ```bash
   vim flatpaks.conf
   ```

4. **Run the setup**
   ```bash
   chmod +x dev_run.sh
   ./dev_run.sh
   ```

## Configuration Files

### packages.conf

Organized package categories:

```bash
# System utilities
SYSTEM_UTILS=(
  htop
  btop
  lazygit
  ...
)

# Development tools
DEV_TOOLS=(
  neovim
  tmux
  git
  ...
)

# Services to enable
SERVICES=(
  NetworkManager.service
  ...
)
```

**Available Categories:**
- `SYSTEM_UTILS` - System monitoring and utilities
- `DEV_TOOLS` - Development environments and tools
- `MAINTENANCE` - System maintenance tools
- `GENERAL_UTILS` - General purpose utilities
- `DESKTOP` - Desktop environment packages
- `BROWSER` - Web browsers
- `MEDIA` - Media players and editors
- `GAMING` - Gaming platforms
- `FONTS` - Font packages
- `SERVICES` - Services to enable at boot

### flatpak-pkg.conf

Flatpak applications using official Flathub IDs:

```bash
# General utilities
GENERAL_UTILS=(
  com.discordapp.Discord
  com.nextcloud.desktopclient.nextcloud
  ...
)

# Web Browser
BROWSER=(
  com.brave.Browser
)
```

**Note:** Use full Flathub application IDs for reliable installation. Find IDs at [flathub.org](https://flathub.org)

## Individual Script Usage

### Arch Package Installer

Installs packages from official repositories and AUR:

```bash
./arch-pkg-setup.sh
```

**Features:**
- Auto-detects and installs AUR helper (yay)
- Separates official repo vs AUR packages
- Interactive package list modification
- Countdown timers (10s default)
- Enables configured services

### Flatpak Installer

Installs Flatpak applications from Flathub:

```bash
./flatpak-pkg-setup.sh
```

**Features:**
- Auto-installs Flatpak if missing
- Configures Flathub repository
- Skips already installed applications
- Installation summary report

## Interactive Features

All scripts support:

### Countdown Timers
- **10-second auto-proceed** - Automatically continues with default action
- Press any key to provide input
- Default actions clearly indicated

### Package Management
During installation, you can:
- **Remove packages** - `r <number>` to remove by index
- **Add packages** - `a <name>` to add custom package
- **Continue** - `d` when done modifying

### Example Session
```
Packages to install:
 1. neovim
 2. tmux
 3. git

⚠️  Automatically proceeding in 10 seconds...
Do you want to proceed with installation? (Y/n) [10s]: 

⚠️  Automatically continuing in 10 seconds...
Do you want to modify the list? (y/N) [10s]: y

Options:
  r <number>  - Remove package by number
  a <name>    - Add package by name
  d           - Done modifying

Enter choice: r 2
✅ Removed: tmux
```

## Post-Installation

After completion, the script offers to reboot:

```
You should reboot the system. Do you want to reboot now? (Y/n):
```

- Press **Enter** or type **y** to reboot
- Type **n** to skip and reboot manually later

## Troubleshooting

### Package Not Found
If packages fail to install:
1. Check spelling in `packages.conf`
2. Verify package exists: `pacman -Ss <package>` or `yay -Ss <package>`
3. Check if it's an AUR package requiring AUR helper

### Flatpak Installation Fails
1. Verify Flatpak ID at [flathub.org](https://flathub.org)
2. Use full application ID (e.g., `com.spotify.Client` not `spotify`)
3. Check internet connection
4. Ensure Flathub repository is configured

### AUR Helper Issues
If yay installation fails:
```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Permission Errors
Ensure you're NOT running as root:
```bash
./dev_run.sh  # Correct
sudo ./dev_run.sh  # Wrong - will error
```

Scripts use sudo only when necessary.

## Customization

### Adding New Categories

Edit `packages.conf`:
```bash
# Custom category
MY_TOOLS=(
  package1
  package2
)
```

Then update `arch-pkg-setup.sh` line 137:
```bash
for category in SYSTEM_UTILS DEV_TOOLS MY_TOOLS ...; do
```

### Changing Timeout Duration

In any script, modify the countdown_prompt call:
```bash
countdown_prompt "Prompt text" "default" 20  # 20 seconds instead of 10
```

### Skipping Steps

Comment out steps in `setup_run.sh`:
```bash
# run_script "./flatpak-pkg-setup.sh" "flatpak package installer"
```

## Tips

- **Test First** - Review package lists before running
- **Backup** - Keep a copy of your configs
- **Incremental** - Run individual scripts if needed
- **Logs** - Scripts provide colored output for easy tracking
- **Dry Run** - Review package lists and modify before confirming

## Contributing

Feel free to:
- Add more package categories
- Improve error handling
- Add new features
- Report issues

## License

This project is provided as-is for personal use.

## Acknowledgments

Inspired by the Arch Linux community and various dotfiles management approaches.

---

**Note:** Always review scripts before running them on your system. This tool modifies system packages and configurations.
