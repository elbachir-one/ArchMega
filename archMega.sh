#part1
printf '\033c'
echo "Welcome to Arch Mega"
pacman --noconfirm -Sy archlinux-keyring
timedatectl set-ntp true
lsblk
cfdisk
mkfs.ext4 /dev/sda3
mount /dev/sda3 /mnt
mkdir /mnt/boot
mkfs.vfat -F32 /dev/sda1
mount /dev/sda1 /mnt/boot
mkswap /dev/sda2
swapon /dev/sda2
pacstrap /mnt base base-devel linux linux-firmware
genfstab -U /mnt >> /etc/fstab
sed '1,/^#part2$/d' `basename $0` > /mnt/archMega.sh
chmod +x /mnt/archMega.sh
arch-chroot /mnt ./archMega.sh
exit

#part2
printf '\033c'
pacman -Sy --noconfirm vim grub networkmanager terminus-font git os-prober efibootmgr
ln -sf /usr/share/zoneinfo/Africa/Casablanca /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
touch /etc/locale.conf
echo "LANG=en_US.UTF-8" > /etc/locale.conf
touch /etc/vconsole.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "FONT=ter-d18b" > /etc/vconsole.conf
echo "Root passwd: "
passwd root
echo "Hostname: "
read hostname
echo $hostname > /etc/hostname
echo "127.0.0.1       localhost" >> /etc/hosts
echo "::1             localhost" >> /etc/hosts
echo "127.0.1.1       $hostname.localdomain $hostname" >> /etc/hosts
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "Enter Username: "
read username
useradd -mG wheel $username
passwd $username
exit
