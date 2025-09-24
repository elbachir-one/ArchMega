#!/usr/bin/env bash
set -e

echo "Welcome to the Arch setup script!"

# Temporary enable NOPASSWD for wheel only so the user types the password once
sudo sed -i.bak 's/^#\s*\(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers

# --- Ask about yay ---
read -rp "Do you want to install yay (AUR helper)? (y/N): " install_yay_choice

# --- DE/WM Selection ---
declare -A environments=(
["1"]="GNOME"
["2"]="KDE Plasma"
["3"]="XFCE"
["4"]="MATE"
["5"]="Sway"
["6"]="Hyprland"
["7"]="i3"
["8"]="dwm"
)

echo "Select a desktop environment/window manager to install (default XFCE):"
for key in $(printf "%s\n" "${!environments[@]}" | sort -n); do
	echo "$key) ${environments[$key]}"
done
read -rp "Enter your choice: " de_choice
de_choice=${de_choice:-3}  # default to 3 = XFCE
env="${environments[$de_choice]}"

if [ -z "$env" ]; then
	echo "Invalid DE/WM choice. Exiting."
	exit 1
fi

# --- Browser Selection ---
declare -A browsers=(
["1"]="brave-bin"
["2"]="chromium"
["3"]="firefox"
["4"]="librewolf-bin"
["5"]="qutebrowser"
["6"]="ungoogled-chromium-bin"
["7"]="zen-browser-bin"
)
echo "Select a browser to install (press Enter to skip, default Chromium):"
for key in $(printf "%s\n" "${!browsers[@]}" | sort -n); do
	echo "$key) ${browsers[$key]}"
done
read -rp "Enter your choice: " browser_choice
browser_choice=${browser_choice:-2}  # default to 2 = Chromium
browser="${browsers[$browser_choice]}"
echo

# --- LightDM (for DEs that use it) ---
lightdm_choice="N"
case "$env" in
	"GNOME"|"KDE Plasma"|"XFCE"|"MATE"|"Sway"|"Hyprland")
		read -rp "Do you want to install and enable LightDM? (y/N): " lightdm_choice
		;;
esac

# --- Store extra packages ---
extra_packages="git go base-devel pipewire pipewire-pulse wireplumber pavucontrol noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-jetbrains-mono-nerd noto-fonts-extra"

# --- Store environment packages ---
declare -A packages
packages["GNOME"]="gnome gnome-terminal nautilus gnome-tweaks gnome-shell-extensions"
packages["KDE Plasma"]="plasma plasma-desktop kde-applications-meta konsole dolphin"
packages["XFCE"]="xfce4 xfce4-goodies xorg"
packages["MATE"]="mate mate-extra caja marco"
packages["Sway"]="sway swaybg swayidle swaylock waybar foot mako grim slurp wofi"
packages["Hyprland"]="hyprland waybar waybar-hyprland xdg-desktop-portal-hyprland hyprland-protocols kitty mako grim slurp wofi"
packages["i3"]="i3 i3status i3lock rofi xterm flameshot"
packages["dwm"]="dwm st dmenu flameshot"

# --- Summary of choices ---
echo
echo "Summary of your choices:"
echo "Install yay: $install_yay_choice"
echo "Desktop/WM: $env"
echo "Browser: ${browser:-None}"
echo "LightDM: $lightdm_choice"
echo "Extra packages: $extra_packages"
echo

read -rp "Press Enter to start installation, or Ctrl+C to cancel..."

# --- Installation begins ---
# Install yay if requested
if [[ "$install_yay_choice" =~ ^[Yy]$ ]]; then
	if ! command -v yay &>/dev/null; then
		echo "Installing yay..."
		tmpdir=$(mktemp -d)
		git clone https://aur.archlinux.org/yay "$tmpdir/yay"
		pushd "$tmpdir/yay"
		makepkg -si --noconfirm
		popd
		rm -rf "$tmpdir"
	else
		echo "yay already installed."
	fi
fi

# --- Install all packages ---
pkglist="${packages[$env]} $extra_packages"
[[ -n "$browser" ]] && pkglist="$pkglist $browser"

if command -v yay &>/dev/null; then
	yay -S --noconfirm $pkglist
else
	sudo pacman -S --noconfirm $pkglist
fi

# --- Post-install setup ---
case "$env" in
	"GNOME"|"KDE Plasma"|"XFCE"|"MATE"|"Sway"|"Hyprland")
		if [[ "$lightdm_choice" =~ ^[Yy]$ ]]; then
			if command -v yay &>/dev/null; then
				yay -S --noconfirm lightdm lightdm-gtk-greeter
			else
				sudo pacman -S --noconfirm lightdm lightdm-gtk-greeter
			fi
			sudo systemctl enable lightdm.service
		fi
		;;
	"i3"|"dwm")
		echo "Installing Xorg and xinit..."
		if command -v yay &>/dev/null; then
			yay -S --noconfirm xorg xorg-xinit
		else
			sudo pacman -S --noconfirm xorg xorg-xinit
		fi
		echo "Creating ~/.xinitrc for $env..."
		wm_exec="exec $env"
		echo "$wm_exec" > "$HOME/.xinitrc"
		chmod +x "$HOME/.xinitrc"
		;;
esac

# --- Restore sudoers line ---
sudo sed -i 's/^\(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/#\1/' /etc/sudoers

echo "Setup complete! You can now reboot and log into $env."
