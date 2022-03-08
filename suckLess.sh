#parte1

printf '\033c'
echo "Welcome to Suckless Power"
sudo pacman --noconfirm -Sy xorg xorg-xinit feh picom ranger scrot webkit2gtk gcr git base-devel terminus-font ttf-jetbrains-mono
ttf-nerd-fonts-symbols
git clone https://github.com/elbachir-one/Suckless-Power
cd Suckless-Power/dwm/
make
sudo make clean install
cd ..
cd dmenu/
sudo make clean install
cd ..
cd st/
sudo make clean install
cd
#parte2

printf '\033c'
touch .xinitrc
echo "setxkbmap us &" > .xinitrc
echo "picom &" >> .xinitrc
echo "feh --bg-fill $HOME/Wallpaper/19.jpg &" >> .xinitrc
echo "exec dwm" >> .xinitrc
git clone https://github.com/elbachir-one/Wallpaper
echo "startx" >> .bash_profile
sudo reboot
