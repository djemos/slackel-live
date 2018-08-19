#!/bin/bash
# Gettext internationalization
#
# Copyright 2016, 2017  Dimitris Tzemos, GR
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# script to create kernel module package and initrd when kernel upgrade and copy to live usb

AUTHOR='Dimitris Tzemos - dijemos@gmail.com'
LICENCE='GPL v3+'
SCRIPT=$(basename "$0")
SCRIPT=$(readlink -f "$SCRIPT")
VER=1.0

if [ -z "$startdir" ]; then
	cd $(dirname "$0")
	startdir="$(pwd)"
	export startdir
fi

if [ "$UID" != "0" ]; then
	echo "You need to be root to run this"
	exit 1
fi

moduleslist="squashfs:overlay:loop:xhci-pci:ohci-pci:ehci-pci:xhci-hcd:uhci-hcd:ehci-hcd:usb-storage:hid:usbhid:i2c-hid:hid-generic:hid-cherry:hid-logitech:hid-logitech-dj:hid-logitech-hidpp:hid-lenovo:hid-microsoft:hid_multitouch:ext3:ext4:isofs:nls_cp437:nls_iso8859-1"

usb_path=`df --output=target | grep LIVE`

MSGSTR="Are you sure your usb is mounted in $usb_path ? 
 If you are sure choose yes"
dialog --title "Be sure for USB mount point" \
	--defaultno \
	--yesno "$MSGSTR" 0 0
retval=$?
if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
	clear
	exit 0
fi

# create packages_dir directory and copy all txz files there
# create list file with the names of packages in packages_dir

# live where packages will install, modules where modules will created, packages_dir contain packages.txz, list files with packages file names
packagesdirectory=$startdir/packages_dir
rootdirectory=$startdir/live
packageslistfile=$startdir/packages_list
modules=$startdir/modules
if ! [ -d $packagesdirectory ]; then
	echo "You have to create a 'packages_dir' directory with packages txz"
	exit
fi

if ! [ -f $packageslistfile ]; then
	echo "You have to create a 'packages_list' file with packages names"
	exit
fi

mkdir -p $packagesdirectory $rootdirectory $modules

# install packages in $rootdirectory
echo "install packages in $rootdirectory"
build-slackware-live.sh --add $packagesdirectory $rootdirectory $packageslistfile

# create module from $rootdirectory directory with xz compression
echo
echo "==================================="
echo "create module from $rootdirectory directory with xz compression"
build-slackware-live.sh --module $rootdirectory $modules 05-kernel.slm  -xz

# build initrd image + efi
echo
echo "==================================="
echo "build initrd image + efi"
build-slackware-live.sh --init / $modules $moduleslist

# copy files to usb
echo
echo "==================================="
echo "copy $modules to $usb_path"
cp -R $modules/* $usb_path
#cp modules/boot/modules/05-kernel.slm /run/media/djemos/LIVE/boot/modules/05-kernel.slm
dialog --title "Delete $rootdirectory and $modules directories ?" \
	--defaultno \
	--yesno "$MSG" 0 0
retval=$?
if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
	exit 0
else
	echo
	echo "==================================="
	echo "delete $rootdirectory $modules directories"
	rm -rf $rootdirectory $modules
fi
