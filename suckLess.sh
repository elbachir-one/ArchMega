#!/usr/bin/env bash
set -euo pipefail

# Reset terminal
printf '\033c'
echo "=== Welcome to Suckless Power ==="

# Install required packages
echo "[*] Installing required packages..."
sudo pacman --noconfirm -S \
	xorg xorg-xinit feh picom ranger scrot webkit2gtk \
	gcr base-devel ttf-jetbrains-mono noto-fonts-emoji \
	noto-fonts-extra noto-fonts-cjk ttf-nerd-fonts-symbols \
	libjpeg-turbo libpng

# Create a directory for suckless builds
mkdir -p "$HOME/Suckless"
cd "$HOME/Suckless"

# Clone and build suckless tools
for repo in dwm dmenu st slstatus slock farbfeld sent; do
	echo "[*] Cloning and installing $repo..."
	git clone "git://git.suckless.org/$repo"
	cd "$repo"
	make
	sudo make clean install
	cd ..
done

# Configure X startup
echo "[*] Configuring .xinitrc..."
cat > "$HOME/.xinitrc" <<EOF
exec dwm
EOF

# Ensure startx runs on login
if ! grep -q "startx" "$HOME/.bash_profile" 2>/dev/null; then
	echo "startx" >> "$HOME/.bash_profile"
fi

echo "[*] Installation complete. Rebooting..."
sudo reboot
