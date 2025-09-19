#!/usr/bin/env bash

# --- Arch Linux Auto Installer ---

# ========================
# part1: Base installation
# ========================
setfont -d
printf '\033c'
echo "Welcome to Arch Mega"

# Show available drives
lsblk -d -o NAME,SIZE,MODEL
echo
read -rp "Enter the drive to install Arch on (e.g., sda, vda, nvme0n1): " drive
device="/dev/$drive"

echo "You selected: $device"
echo "WARNING: This will ERASE ALL DATA on $device!"
read -rp "Are you sure you want to continue? (yes/NO): " confirm

if [[ "$confirm" != "yes" ]]; then
	echo "Aborted."
	exit 1
fi

echo "Selected device: $device"

# Update keyring
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 1/' /etc/pacman.conf
pacman -Sy --noconfirm
pacman --noconfirm -S archlinux-keyring

# Partition the disk
parted --script "$device" -- mklabel gpt \
	mkpart ESP fat32 1MiB 1024MiB \
	set 1 esp on \
	mkpart primary 1024MiB 100%

# Format boot
mkfs.fat -F32 "${device}1"

# Setup LUKS
read -rsp "Enter password for encrypted disk: " encrytpasswd
echo
read -rsp "Confirm password: " encrytpasswd_confirm
echo

if [ "$encrytpasswd" != "$encrytpasswd_confirm" ]; then
	echo "Passwords do not match. Exiting."
	exit 1
fi

# Encrypt and open
echo -n "$encrytpasswd" | cryptsetup --use-random luksFormat "${device}2"
echo -n "$encrytpasswd" | cryptsetup luksOpen "${device}2" cryptlvm

# Setup LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -l 100%FREE -n root vg0
lvreduce --size -256M vg0/root

# Format logical volumes
mkfs.ext4 /dev/vg0/root

# Mount partitions
mount /dev/vg0/root /mnt
mount --mkdir "${device}1" /mnt/boot

# Install base system
pacstrap -K /mnt linux linux-firmware linux-headers base base-devel vim \
	terminus-font efibootmgr git go networkmanager iwd openssh mtools ntfs-3g \
	dosfstools reflector intel-ucode amd-ucode bluez bluez-utils alsa-utils \
	bash-completion nano lvm2 cryptsetup freetype2 libisoburn fuse3 curl wget \
	usbutils

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab

# UUID copy to the chroot env
cryptUUID=$(blkid -s UUID -o value "${device}2")
echo "$cryptUUID" > /mnt/cryptuuid

# Copy second stage of script into new system
sed '1,/^#part2$/d' "$0" > /mnt/archMega.sh
chmod +x /mnt/archMega.sh

# Chroot into system
arch-chroot /mnt ./archMega.sh

exit

#part2
# ========================
# part2: System configure
# ========================
printf '\033c'

# Prompt for bootloader
echo "Which bootloader do you want to use?"
echo "1) systemd-boot (default)"
echo "2) GRUB"
read -rp "Enter choice [1-2]: " boot_choice
boot_choice=${boot_choice:-1}  # default to systemd-boot
echo

# Username
read -rp "Enter the new username: " username
while [[ -z "$username" ]]; do
	echo "Username cannot be empty."
	read -rp "Enter the new username: " username
done

# User password
read -rsp "Enter password for user $username: " userpassword
echo
read -rsp "Confirm password for user $username: " userpassword2
echo
if [[ "$userpassword" != "$userpassword2" ]]; then
	echo "Passwords do not match. Exiting."
	exit 1
fi

# Root password
read -rsp "Enter root password: " rootpassword
echo
read -rsp "Confirm root password: " rootpassword2
echo
if [[ "$rootpassword" != "$rootpassword2" ]]; then
	echo "Passwords do not match. Exiting."
	exit 1
fi

# Hostname
read -rp "Enter hostname [ARCH]: " hostname
hostname=${hostname:-ARCH}

# Keymap
echo "Available keymaps (examples: us, fr, de, uk, es):"
read -rp "Enter keymap [us]: " keymap
keymap=${keymap:-us}

# Locale
echo "Choose locale:"
select locale in \
	"en_US.UTF-8 UTF-8" \
	"en_GB.UTF-8 UTF-8" \
	"fr_FR.UTF-8 UTF-8" \
	"de_DE.UTF-8 UTF-8" \
	"es_ES.UTF-8 UTF-8"; do
	[[ -n "$locale" ]] && break
done

# Timezone & clock
echo "Choose your timezone (examples: Africa/Casablanca, Europe/Paris, America/New_York, Asia/Tokyo)"
read -rp "Enter timezone (or leave blank to autodetect): " zone
if [[ -z "$zone" ]]; then
	zone=$(curl -sf https://ipapi.co/timezone/) || zone="UTC"
	echo "Autodetected timezone: $zone"
fi

ln -sf "/usr/share/zoneinfo/$zone" /etc/localtime

hwclock --systohc

# Locale
echo "$locale" >> /etc/locale.gen
locale-gen
echo "LANG=${locale%% *}" > /etc/locale.conf

# Console keymap & font
echo "KEYMAP=$keymap" > /etc/vconsole.conf
echo "FONT=ter-128n" >> /etc/vconsole.conf

# Pacman config
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 1/' /etc/pacman.conf

# Hostname
echo "$hostname" > /etc/hostname

# Root password
echo "root:$rootpassword" | chpasswd

# Create user
useradd -mG wheel "$username"
echo "$username:$userpassword" | chpasswd

# Enable wheel group sudo
sed -i 's/^[[:space:]]*# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# mkinitcpio
sed -i 's/^HOOKS=.*/HOOKS=(base udev keyboard autodetect microcode modconf kms keymap lvm2 consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf

# Hosts
cat <<EOF > /etc/hosts
127.0.0.1       localhost
::1             localhost
127.0.1.1       $hostname.localdomain $hostname
EOF

systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable bluetooth

# Bootloader installation
if [ "$boot_choice" -eq 1 ]; then
	# systemd-boot
	bootctl install

	cryptUUID=$(cat cryptuuid)

	tee > /boot/loader/loader.conf <<EOF
default arch
timeout 5
console-mode max
EOF

tee > /boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=UUID=$cryptUUID:cryptlvm allow-discards root=/dev/vg0/root rw
EOF
else
	# GRUB
	pacman -S --noconfirm grub

	grep -q "^GRUB_ENABLE_CRYPTODISK" /etc/default/grub || echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

	cryptUUID=$(cat cryptuuid)

	sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 cryptdevice=UUID=$cryptUUID:cryptlvm\"|" /etc/default/grub

	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
	grub-mkconfig -o /boot/grub/grub.cfg
fi

# DNS
tee > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Re-build the initramfs
echo "Rebuilding the Initramfs"
mkinitcpio -P

echo "Installation complete! Type reboot."
echo "The User name is ($username) and the password is ($userpassword) also the root password is ($rootpassword)"
exit
