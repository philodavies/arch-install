#!/bin/sh
# Luke's Auto Rice Boostrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# License: GNU GPLv3

### SETUP ###

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/philodavies/dotfiles.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/philodavies/arch-install/master/progs.csv"

### FUNCTIONS ###

installpkg(){ pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}

error() { clear; printf "ERROR:\\n%s\\n" "$1" >&2; exit 1;}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
	total=$(grep '^,' /tmp/progs.csv | wc -l)
    n=1
	while IFS=, read -r tag program comment; do
		echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") continue ;;
			*) maininstall "$program" "$comment" ;;
		esac
		n=$((n+1))
	done < /tmp/progs.csv ;}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
pacman --noconfirm --needed -Sy dialog || error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

# Get and verify username and password.
getuserandpass || error "User exited."

### The rest of the script requires no user input.

for x in curl base-devel git ntp zsh; do
	dialog --title "Installation" --infobox "Installing \`$x\` which is required to install and configure other programs." 5 70
	installpkg "$x"
done

adduserandpass || error "Error adding username and/or password."

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has privileges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Setup bootloader (rEFInd)
refind-install
mv /boot/* /efi/
sed -i '1,2d' /efi/refind_linux.conf

# Setup locale
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Create user's home dirs
sudo -u "$name" mkdir "/home/$name/"{Documents,Pictures,Videos,Downloads}

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh"

# Enable NetworkManager
systemctl enable NetworkManager

# Install dotfiles
config="sudo -u $name git --git-dir=/home/$name/Git/.cfg/ --work-tree=/home/$name"
sudo -u "$name" mkdir -p "/home/$name/Git"
$config clone --bare "$dotfilesrepo" "/home/$name/Git/.cfg"
$config checkout

sh "/home/$name/.config/install/install.sh" "$name"

# Last message! Install complete!
finalize
clear
