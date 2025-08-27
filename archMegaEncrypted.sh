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
encrytpasswd="arch"
echo "$encrytpasswd" | cryptsetup --use-random luksFormat "${device}2"
echo "$encrytpasswd" | cryptsetup luksOpen "${device}2" cryptlvm

# Setup LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate --size 5G -n root vg0
lvcreate --size 1G -n swap vg0
lvcreate -l 100%FREE -n home vg0
lvreduce --size -256M vg0/home

# Format logical volumes
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home
mkswap /dev/vg0/swap
swapon /dev/vg0/swap

# Mount partitions
mount /dev/vg0/root /mnt
mount --mkdir /dev/vg0/home /mnt/home
mount --mkdir "${device}1" /mnt/boot

# Install base system
pacstrap -K /mnt linux linux-firmware linux-headers base base-devel vim \
	terminus-font efibootmgr git go networkmanager iwd openssh mtools ntfs-3g \
	dosfstools reflector intel-ucode amd-ucode bluez bluez-utils alsa-utils \
	bash-completion nano lvm2 cryptsetup

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab

# UUID copy
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

# Variables
rootpassword="arch"
username="arch"
userpassword="arch"
hostname="ARCH"

# Prompt for bootloader
echo "Which bootloader do you want to use?"
echo "1) systemd-boot (default)"
echo "2) GRUB"
read -rp "Enter choice [1-2]: " boot_choice
boot_choice=${boot_choice:-1}  # default to systemd-boot

# Timezone
zone=$(curl -sf https://ipapi.co/timezone/)

ln -sf /usr/share/zoneinfo/$zone /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Console keymap & font
echo "KEYMAP=fr" > /etc/vconsole.conf
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
options cryptdevice=UUID=$cryptUUID:cryptlvm allow-discards resume=/dev/vg0/swap root=/dev/vg0/root rw
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
