#!/bin/sh
# Luke's Auto Rice Boostrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# License: GNU GPLv3

### SETUP ###

[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/philodavies/arch-install/master/progs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"

### FUNCTIONS ###

installpkg(){ pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}

error() { clear; printf "ERROR:\\n%s\\n" "$1" >&2; exit 1;}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "Enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	}

manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	dialog --infobox "Installing \"$1\", an AUR helper..." 4 50
	cd /tmp || exit 1
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return 1) ;}

aurinstall() { \
	dialog --title "Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
    total=$(grep '^A,' /tmp/progs.csv | wc -l)
	aurinstalled=$(pacman -Qqm)
    n=1
	while IFS=, read -r tag program comment; do
		echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurinstall "$program" "$comment" ;;
			*) continue ;;
		esac
		n=$((n+1))
	done < /tmp/progs.csv ;}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Get the username.
getuserandpass || error "User exited."

### The rest of the script requires no user input.

manualinstall $aurhelper || error "Failed to install AUR helper."

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has sudo privilege.
installationloop

# Last message! Install complete!
finalize
clear
