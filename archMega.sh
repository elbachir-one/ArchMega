#!/usr/bin/env bash

# Arch Mega Installer

# ========================
# part1: Base installation
# ========================
setfont -d
printf '\033c'
echo "Welcome to Arch Mega"

device="/dev/vda"

# Update keyring

# Update system and partition
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 1/' /etc/pacman.conf
pacman -Sy --noconfirm
pacman --noconfirm -S archlinux-keyring

# Partition the disk
parted --script "${device}" -- mklabel gpt \
  mkpart ESP fat32 1Mib 1024MiB \
  set 1 esp on \
  mkpart primary 1024MiB 100%

# Format boot
mkfs.fat -F32 /dev/vda1
mkfs.ext4 /dev/vda2

mount /dev/vda2 /mnt
mkdir /mnt/boot
mount /dev/vda1 /mnt/boot

# Install base system
pacstrap -K /mnt linux linux-firmware linux-headers base base-devel vim terminus-font efibootmgr git go

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab

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
username="sh"
userpassword="arch"
hostname="ARCH"

# Timezone
ln -sf /usr/share/zoneinfo/Africa/Casablanca /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Console keymap & font
echo "KEYMAP=fr" > /etc/vconsole.conf
echo "FONT=ter-d18b" >> /etc/vconsole.conf

# Pacman config
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 1/' /etc/pacman.conf

# Hostname
echo "$hostname" > /etc/hostname

# Root password
echo "root:$rootpassword" | chpasswd

# Create user
useradd -m -s /bin/bash "$username"
echo "$username:$userpassword" | chpasswd
usermod -aG wheel "$username"

# Enable wheel group sudo
sed -i 's/^[[:space:]]*# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

cat <<EOF > /etc/hosts
127.0.0.1       localhost
::1             localhost
127.0.1.1       $hostname.localdomain $hostname
EOF

# Network
cat > /etc/systemd/network/en.network <<EOF
[Match]
Name=en*
[Network]
DHCP=ipv4
EOF

systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd

# Systemd Boot
bootctl install

UUID=$(blkid -o value -s UUID /dev/vda2)

cat > /boot/loader/loader.conf <<EOF
default arch
timeout 5
console-mode max
EOF

cat > /boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=$UUID rw video="1360x768"
EOF

# DNS
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Re-build the Iinitramfs
mkinitcpio -P

# Set up YAY
git clone https://aur.archlinux.org/yay
cd yay/ && makepkg -si
cd .. && rm -rf yay/

echo "Installation complete! Type reboot."
exit
