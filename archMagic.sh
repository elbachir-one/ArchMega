#part1
printf '\033c'
echo "Welcome to Arch Magic"
pacman --noconfirm -Sy archlinux-keyring
timedatectl set-ntp true
lsblk
cfdisk
mkfs.ext4 /dev/vda3
mount /dev/vda3 /mnt
mkdir /mnt/boot
mkfs.vfat -F32 /dev/vda1
mount /dev/vda1 /mnt/boot
mkswap /dev/vda2
swapon /dev/vda2
pacstrap /mnt base linux
genfstab -U /mnt >> /etc/fstab
sed '1,/^#part2$/d' `basename $0` > /mnt/archMagic.sh
chmod +x /mnt/archMagic.sh
arch-chroot /mnt ./archMagic.sh
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
echo "KEYMAP=fr" >> /etc/vconsole.conf
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
