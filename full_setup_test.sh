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

#Checking Drive Size
DRIVE_SIZE=$(lsblk -b -d -n -o SIZE "$DRIVE")
MIN_SIZE=$((30 * 1024 * 1024 * 1024))  # 30GB in bytes
#MIN_SIZE=$((125 * 1024 * 1024 * 1024))  # 125GB in bytes
if [ "$DRIVE_SIZE" -lt "$MIN_SIZE" ]; then
    print_error "Drive too small! Need at least 125GB"
    exit 1
fi

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

## Create partitions using parted
#parted -s "$DRIVE" mklabel gpt
#parted -s "$DRIVE" mkpart primary fat32 1MiB 1GiB
#parted -s "$DRIVE" set 1 esp on
#parted -s "$DRIVE" mkpart primary btrfs 1GiB 101GiB
#parted -s "$DRIVE" mkpart primary linux-swap 101GiB 113GiB
#parted -s "$DRIVE" mkpart primary btrfs 113GiB 100%

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
pacstrap /mnt base base-devel linux linux-headers linux-firmware linux-zen linux-zen-headers linux-lts linux-lts-headers intel-ucode amd-ucode git curl neovim networkmanager pipewire sudo 

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
echo "Examples: America/New_York, Europe/London, Asia/Tokyo"
ls /usr/share/zoneinfo/
read -rp "Enter region (e.g., America): " REGION
ls "/usr/share/zoneinfo/$REGION/"
read -rp "Enter city (e.g., New_York): " CITY
ln -sf "/usr/share/zoneinfo/$REGION/$CITY" /etc/localtime
hwclock --systohc
print_info "Timezone set to $REGION/$CITY"
echo

# Locale selection
print_info "=== Locale Configuration ==="
echo "Common locales:"
echo "  en_US.UTF-8"
echo "  en_GB.UTF-8"
echo "  de_DE.UTF-8"
echo "  es_ES.UTF-8"
echo "  fr_FR.UTF-8"
read -rp "Enter locale (e.g., en_US.UTF-8): " LOCALE
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
print_info "Locale set to $LOCALE"
echo

# Keyboard layout
print_info "=== Keyboard Layout Configuration ==="
echo "Common layouts: us, uk, de, fr, es"
read -rp "Enter keyboard layout (e.g., us): " KEYMAP
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
print_info "Set root password:"
passwd

# Create user
print_info "=== User Creation ==="
read -rp "Enter username: " USERNAME
useradd -m -G wheel,audio,video,storage -s /bin/bash "$USERNAME"
print_info "Set password for $USERNAME:"
passwd "$USERNAME"

# Enable sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

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
initrd  /intel-ucode.img
initrd  /amd-ucode.img
options root=UUID=$ROOT_UUID rw
ARCH_EOF

cat > /boot/loader/entries/arch-zen.conf << ZEN_EOF
title   Arch Linux (Zen)
linux   /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
initrd  /intel-ucode.img
initrd  /amd-ucode.img
options root=UUID=$ROOT_UUID rw
ZEN_EOF

cat > /boot/loader/entries/arch-lts.conf << LTS_EOF
title   Arch Linux (LTS)
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux-lts.img
options root=UUID=$ROOT_UUID rw
LTS_EOF

print_info "Bootloader configured with entries for all kernels"

#Installing HyDE Hyprland
print_info "Setting up HyDE for user $USERNAME..."
# Ensure ownership before switching user
chown -R "$USERNAME:$USERNAME" /home/"$USERNAME"

if su - "$USERNAME" -c "git clone --depth 1 https://github.com/HyDE-Project/HyDE ~/HyDE && cd ~/HyDE/Scripts && ./install.sh"; then
    print_info "=== HyDE Installation Completed ==="
else
    print_warn "HyDE installation encountered issues, check logs"
fi

#Installing personal apps and dotfiles
if su - "$USERNAME" -c "git clone https://github.com/mcbk51/arch_setup.git ~/arch_setup && cd ~/arch_setup && ./setup_run.sh"; then
    print_info "=== Personal setup completed ==="
else
    print_warn "Personal setup encountered issues, check logs"
fi
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

