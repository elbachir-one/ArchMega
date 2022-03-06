# This is ArchMega.
** ArchMega is a Script to Install ArchLinux.
### Step 1: loading your keyboard layout.

loadkey ...

### Step 2: install git.

pacman -Sy git

### Step 3: clone the script.

git clone https://github.com/elbachir-one/ArchMega

### Step 4: copy the "ArchMega.sh" to the root.

cp ArchMega/ArchMega.sh /root

### Step 5: make the script executable.

chmod +x ArchMega.sh

### Step 6: run the script.

./ArchMega.sh

Note1: The script is going to launch cfdisk and you have to creat 3 partition, the first one is EFI and the second is the SWAP partition and the 3 is the filesystem in this order.

Note2: After the installation is finished you need to reboot the system.

*** Et voilà
