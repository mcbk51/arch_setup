#!/bin/bash
# Arch Linux Minimal Installation Script
# Run this script from the Arch ISO
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

print_info "=== Arch Linux Minimal Installation Script ==="
echo

# Set NTP
print_info "Setting system time..."
timedatectl set-ntp true
sleep 2

# List available drives
print_info "Available drives:"
lsblk -d -o NAME,SIZE,TYPE | grep disk
echo

# Ask for drive
read -rp "Enter the drive to install on (e.g., sda, nvme0n1, vda): " DRIVE
DRIVE="/dev/${DRIVE}"

if [ ! -b "$DRIVE" ]; then
    print_error "Drive $DRIVE does not exist!"
    exit 1
fi

print_warn "WARNING: All data on $DRIVE will be destroyed!"
read -rp "Continue? (yes/no) [yes]: " CONFIRM
CONFIRM=${CONFIRM:-yes}

if [ "$CONFIRM" == "no" ]; then
    print_error "Installation aborted."
    exit 1
fi

# Partition the drive
print_info "Partitioning $DRIVE..."

# Determine partition naming scheme
if [[ $DRIVE == *"nvme"* ]] || [[ $DRIVE == *"mmcblk"* ]]; then
    PART1="${DRIVE}p1"
    PART2="${DRIVE}p2"
    PART3="${DRIVE}p3"
    PART4="${DRIVE}p4"
else
    PART1="${DRIVE}1"
    PART2="${DRIVE}2"
    PART3="${DRIVE}3"
    PART4="${DRIVE}4"
fi
# Create partitions using parted (fits within ~30GB)
parted -s "$DRIVE" mklabel gpt
parted -s "$DRIVE" mkpart primary fat32 1MiB 1GiB
parted -s "$DRIVE" set 1 esp on
parted -s "$DRIVE" mkpart primary btrfs 1GiB 11GiB
parted -s "$DRIVE" mkpart primary linux-swap 11GiB 13GiB
parted -s "$DRIVE" mkpart primary btrfs 13GiB 100%

print_info "Partitions created:"
lsblk "$DRIVE"
sleep 2

# Format partitions
print_info "Formatting partitions..."
mkfs.fat -F32 "$PART1"
mkfs.btrfs -f "$PART2"
mkswap "$PART3"
mkfs.btrfs -f "$PART4"

# Mount partitions
print_info "Mounting partitions..."
mount "$PART2" /mnt

mkdir -p /mnt/boot
mount "$PART1" /mnt/boot

mkdir -p /mnt/home
mount "$PART4" /mnt/home

swapon "$PART3"

print_info "Partitions mounted:"
lsblk "$DRIVE"
sleep 2

# Install base system
print_info "Installing base system (this may take a while)..."
pacstrap /mnt base base-devel linux linux-headers linux-firmware linux-zen linux-zen-headers linux-lts linux-lts-headers git curl neovim networkmanager  sudo


# Enable multilib repository
print_info "Enabling multilib repository..."
# Check if multilib exists (commented or uncommented)
if grep -q "^\[multilib\]" /mnt/etc/pacman.conf; then
    print_info "Multilib already enabled"
elif grep -q "^#\[multilib\]" /mnt/etc/pacman.conf; then
    print_info "Uncommenting existing multilib section..."
    sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /mnt/etc/pacman.conf
else
    print_info "Adding multilib section..."
    cat << 'EOF' >> /mnt/etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
fi

# Update package database inside chroot
arch-chroot /mnt pacman -Sy --noconfirm

# Generate fstab
print_info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Create chroot configuration script
print_info "Creating chroot configuration script..."
cat > /mnt/root/arch_chroot_setup.sh << 'CHROOT_EOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}
# Timezone selection
print_info "=== Timezone Configuration ==="

# Try to detect timezone based on IP geolocation
print_info "Attempting to detect your location..."
DETECTED_TZ=""
if command -v curl >/dev/null 2>&1; then
    DETECTED_TZ=$(curl -s --max-time 5 "http://ip-api.com/line/?fields=timezone" 2>/dev/null || echo "")
fi

if [ -n "$DETECTED_TZ" ] && [ -f "/usr/share/zoneinfo/$DETECTED_TZ" ]; then
    print_info "Detected timezone: $DETECTED_TZ"
    REGION=$(echo "$DETECTED_TZ" | cut -d'/' -f1)
    CITY=$(echo "$DETECTED_TZ" | cut -d'/' -f2-)
else
    print_info "Could not detect location automatically"
    REGION=""
    CITY=""
fi

# Show common timezones with detected one first
echo "Select timezone:"
COUNTER=1
declare -a TZ_OPTIONS

if [ -n "$DETECTED_TZ" ]; then
    echo "$COUNTER) $DETECTED_TZ (detected)"
    TZ_OPTIONS[$COUNTER]="$DETECTED_TZ"
    ((COUNTER++))
fi

# Common timezones
COMMON_TZ=("America/New_York" "America/Los_Angeles" "America/Chicago" "Europe/London" "Europe/Paris" "Asia/Tokyo" "Australia/Sydney")

for tz in "${COMMON_TZ[@]}"; do
    if [ "$tz" != "$DETECTED_TZ" ] && [ $COUNTER -le 5 ]; then
        echo "$COUNTER) $tz"
        TZ_OPTIONS[$COUNTER]="$tz"
        ((COUNTER++))
    fi
done

echo "6) Manual entry"

read -rp "Enter choice [1]: " TZ_CHOICE
TZ_CHOICE=${TZ_CHOICE:-1}

if [ "$TZ_CHOICE" == "6" ]; then
    echo "Examples: America/New_York, Europe/London, Asia/Tokyo"
    ls /usr/share/zoneinfo/
    read -rp "Enter region (e.g., America): " REGION
    ls "/usr/share/zoneinfo/$REGION/"
    read -rp "Enter city (e.g., New_York): " CITY
    SELECTED_TZ="$REGION/$CITY"
elif [ -n "${TZ_OPTIONS[$TZ_CHOICE]}" ]; then
    SELECTED_TZ="${TZ_OPTIONS[$TZ_CHOICE]}"
    REGION=$(echo "$SELECTED_TZ" | cut -d'/' -f1)
    CITY=$(echo "$SELECTED_TZ" | cut -d'/' -f2-)
else
    print_warn "Invalid choice, using America/New_York"
    SELECTED_TZ="America/New_York"
    REGION="America"
    CITY="New_York"
fi

ln -sf "/usr/share/zoneinfo/$SELECTED_TZ" /etc/localtime
hwclock --systohc
print_info "Timezone set to $SELECTED_TZ"
echo
# Locale selection
print_info "=== Locale Configuration ==="
echo "Select locale:"
echo "1) en_US.UTF-8 (default)"
echo "2) en_GB.UTF-8"
echo "3) de_DE.UTF-8"
echo "4) es_ES.UTF-8"
echo "5) fr_FR.UTF-8"
read -rp "Enter choice [1]: " LOCALE_CHOICE
LOCALE_CHOICE=${LOCALE_CHOICE:-1}

case $LOCALE_CHOICE in
    1) LOCALE="en_US.UTF-8" ;;
    2) LOCALE="en_GB.UTF-8" ;;
    3) LOCALE="de_DE.UTF-8" ;;
    4) LOCALE="es_ES.UTF-8" ;;
    5) LOCALE="fr_FR.UTF-8" ;;
    *) LOCALE="en_US.UTF-8" ;;
esac

echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
print_info "Locale set to $LOCALE"
echo
# Keyboard layout
print_info "=== Keyboard Layout Configuration ==="
echo "Select keyboard layout:"
echo "1) us (default)"
echo "2) uk"
echo "3) de"
echo "4) es"
echo "5) fr"
read -rp "Enter choice [1]: " KEYMAP_CHOICE
KEYMAP_CHOICE=${KEYMAP_CHOICE:-1}

case $KEYMAP_CHOICE in
    1) KEYMAP="us" ;;
    2) KEYMAP="uk" ;;
    3) KEYMAP="de" ;;
    4) KEYMAP="es" ;;
    5) KEYMAP="fr" ;;
    *) KEYMAP="us" ;;
esac

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
print_info "Keyboard layout set to $KEYMAP"
echo

# Hostname
read -rp "Enter hostname for this machine: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1   localhost
::1         localhost
HOSTS_EOF
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Root password
ROOT_PASS_SET=false
while [ "$ROOT_PASS_SET" = false ]; do
  print_info "Set root password:"
  if passwd; then
    ROOT_PASS_SET=true
    print_info "Root password set successfully"
  else
    print_warn "Failed to set root password (passwords may not match or are invalid)"
    read -rp "Try again? (yes/no) [yes]: " TRY_AGAIN
    TRY_AGAIN=${TRY_AGAIN: -yes}
    if [ "$TRY_AGAIN" == "no" ]; then
      print_error "Root password is required. Exiting..."
      exit 1
    fi
      
  fi
  
done

# Create user
print_info "=== User Creation ==="
read -rp "Enter username: " USERNAME
useradd -m -G wheel,audio,video,storage -s /bin/bash "$USERNAME"

USER_PASS_SET=false
while [ "$USER_PASS_SET" = false ]; do
    print_info "Set password for $USERNAME:"
    if passwd "$USERNAME"; then
        USER_PASS_SET=true
        print_info "User password set successfully"
    else
        print_warn "Failed to set user password (passwords may not match or are invalid)"
        read -rp "Try again? (yes/no) [yes]: " TRY_AGAIN
        TRY_AGAIN=${TRY_AGAIN:-yes}
        if [ "$TRY_AGAIN" == "no" ]; then
            print_error "User password is required. Exiting..."
            exit 1
        fi
    fi
done

# Enable sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Clone git repository to user's home
print_info "===Install Repo Setup ==="
read -rp "Would you like to clone install repo to user's home? (yes/no) [no]: " CLONE_REPO 
CLONE_REPO=${CLONE_REPO:-no}
REPO_URL="https://github.com/mcbk51/arch_setup.git"

if [ "$CLONE_REPO" == "yes" ]; then 
  read -rp "Enter directory name (leave empty for default): " DIR_NAME
  
  print_info "Cloning repository..."
  if [ -z "$DIR_NAME" ]; then
    su - "$USERNAME" -c "git clone '$REPO_URL'"
  else
    su - "$USERNAME" -c "git clone '$REPO_URL' '$DIR_NAME'"
  fi

  if [ $? -eq 0 ]; then
    print_info "Repository cloned successfully to /home/$USERNAME/"
  else
    print_warn "Failed to clone repository"
  fi 
fi


# Enable NetworkManager
print_info "Enabling NetworkManager..."
systemctl enable NetworkManager

# Install and configure systemd-boot
print_info "Installing systemd-boot bootloader..."
bootctl install

# Get root partition UUID
ROOT_PART=$(findmnt -n -o SOURCE /)
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")

# Create bootloader entry
mkdir -p /boot/loader/entries

cat > /boot/loader/loader.conf << 'LOADER_EOF'
default arch.conf
timeout 3
console-mode max
editor no
LOADER_EOF

cat > /boot/loader/entries/arch.conf << ARCH_EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw
ARCH_EOF

cat > /boot/loader/entries/arch-zen.conf << ZEN_EOF
title   Arch Linux (Zen)
linux   /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
options root=UUID=$ROOT_UUID rw
ZEN_EOF

cat > /boot/loader/entries/arch-lts.conf << LTS_EOF
title   Arch Linux (LTS)
linux   /vmlinuz-linux-lts
initrd  /initramfs-linux-lts.img
options root=UUID=$ROOT_UUID rw
LTS_EOF

print_info "Bootloader configured with entries for all kernels"
print_info "=== Configuration Complete ==="
echo
print_info "System is ready!"
CHROOT_EOF

chmod +x /mnt/root/arch_chroot_setup.sh

print_info "=== Base Installation Complete ==="
echo
print_info "Next steps:"
echo "  1. arch-chroot /mnt /root/arch_chroot_setup.sh  - Configure system"
echo "  2. exit (if you chrooted manually)"
echo "  3. umount -R /mnt"
echo "  4. reboot"
echo

# Ask what to do next
echo
PS3="What would you like to do? "
options=("Run chroot configuration now" "Drop to shell (manual chroot)" "Exit to finish manually")
select opt in "${options[@]}"
do
    case $opt in
        "Run chroot configuration now")
            print_info "Running chroot configuration..."
            arch-chroot /mnt /root/arch_chroot_setup.sh
            print_info "Configuration complete!"
            echo
            read -rp "Unmount and reboot now? (yes/no) [yes]: " REBOOT
            REBOOT=${REBOOT:-yes}
            if [ "$REBOOT" != "no" ]; then
                umount -R /mnt
                reboot
            else
                print_info "Remember to run: umount -R /mnt && reboot"
            fi
            break
            ;;
        "Drop to shell (manual chroot)")
            print_info "Dropping to shell. Run: arch-chroot /mnt /root/arch_chroot_setup.sh"
            break
            ;;
        "Exit to finish manually")
            print_info "Exiting. Run: arch-chroot /mnt /root/arch_chroot_setup.sh"
            break
            ;;
        *) echo "Invalid option";;
    esac
done
