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

AUTHOR='Dimitris Tzemos - dijemos@gmail.com'
LICENCE='GPL v3+'
SCRIPT=$(basename "$0")
SCRIPT=$(readlink -f "$SCRIPT")
VER=1.0

version() {
  echo "Slackel USB installer and persistent creator for 32 and EFI/UEFI 64 v$VER"
  echo " by $AUTHOR"
  echo "Licence: $LICENCE"
}
usage() {
  echo 'install_on_usb.sh [-h/--help] [-v/--version]'
  echo ' -h, --help: this usage message'
  echo ' -v, --version: the version author and licence'
  echo ''
  echo "`basename $0` --usb isoname device"
  echo "`basename $0` --persistent 32|64 device"
  echo ''
  echo '-> --usb option installs syslinux on a USB key using an ISO (specify path to image and device)'
  echo '-> The script will ask user to confirm the device specified'
  echo '-> It will also optionally create a persistent ext3 file.'
  echo ''
  echo '-> --persistent option creates a persistent ext3 file after installation, if user did not do so then'
  echo '-> specify architecture and device'
  echo '-> No need to specify path to iso because Slackel Live is already installed'
  exit 1
}

if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
version
  exit 0
fi
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
usage
fi
#if [ $(id -ru) -ne 0 ]; then
#echo "Error : you must run this script as root" >&2
#  exit 2
#fi

LIVELABEL="LIVE" #edit in init script too
CWD=`pwd`
CMDERROR=1
PARTITIONERROR=2
FORMATERROR=3
BOOTERROR=4
INSUFFICIENTSPACE=5
persistent_file=""
ENCRYPT=""
SCRIPT_NAME="$(basename $0)"
NAME="persistent"
ENCRYPT=""
SVER=14.2

function check_root(){
# make sure I am root
if [ `id -u` != "0" ]; then
	echo "ERROR: You need to be root to run $SCRIPT_NAME"
	echo "The install_on_usb_uefi.sh script needs direct access to your boot device."
	echo "Use sudo or kdesudo or similar wrapper to execute this."
	exit 1
fi
}


function create_link_for_other_distros(){
# if we run the script from other distro's e.g. ubuntu 
# which have mbr.bin installed in /usr/lib/syslinux/ 
# we need a symbolic to /usr/share/syslinux
if [ ! -f /etc/slackware-version ]; then
	if [ -f /usr/lib/syslinux/mbr.bin ]; then
	 if [ ! -f /usr/share/syslinux/mbr.bin ]; then
		sudo ln --symbolic /usr/lib/syslinux/mbr.bin  /usr/share/syslinux/mbr.bin
	 fi 
	fi
	
	if [ -f /usr/lib/syslinux/gptmbr.bin ]; then
	 if [ ! -f /usr/share/syslinux/gptmbr.bin ]; then
		sudo ln --symbolic /usr/lib/syslinux/gptmbr.bin  /usr/share/syslinux/gptmbr.bin
	 fi 
	fi 
fi
}	

function find_iso(){
isoname=$1
if [ -f "$isoname" ]
then
	isoname=$1
	iso_arch="${isoname##*/}"
	iso_arch="${iso_arch##*live}"
	iso_arch="${iso_arch%%-*}"
	if [ "$iso_arch" != "64" ]; then
		iso_arch=32
	fi
else
	echo "'Sorry, $isoname iso file does not exist"
	exit
fi
}

function check_if_file_iso_exists(){
isoname=$1
if [ -f "$isoname" ]; then
	isonamef="${isoname##*/}"
	isonamef="${isonamef%%-*}"

	if [ "$isonamef" == "slackellive64" ]; then
		iso_arch=64
	elif [ "$isonamef" == "slackellive" ]; then
		iso_arch=32
	else
		echo "You provide the wrong iso image"
		exit
	fi
else
	echo "You provide the wrong iso image"
    exit	
fi	
}

function check_device(){
installmedia=$1
msgdev=$1
#Be sure do not format hard disk
disk=`echo $installmedia | cut -c6-8`  
 if [ "$disk" == "sda" ] || [ "$disk" == "hda" ]; then
	echo "You cannot install to /dev/$disk hard disk drive"
	exit
 fi
 
 # check if usb device pluged in
 disks=`cat /proc/partitions | sed 's/  */:/g' | cut -f5 -d: | sed -e /^$/d -e /[1-9]/d -e /^sr0/d -e /loop/d -e /^sda/d`
 disk=`echo $installmedia | cut -c6-8` 
 
 installmedia="" ## clear the variable
	for usb in $disks; do
		if [ "$usb" == "$disk" ]; then
			installmedia="/dev/$usb"
		fi	
		done
if [ "$installmedia" == "" ] || [ "$installmedia" == NULL ]; then
	echo "There is no removable usb device $msgdev attached to your system"
	exit
else
echo "========================================="
echo "										   "
echo "Removable device is $installmedia        "
echo "										   "
echo "========================================="
flag=*
for n in $installmedia$flag ; do umount $n > /dev/null 2>&1; done
#mount_point=`mount | grep $installmedia | cut -d : -f 1 -d " "` 
#umount $mount_point > /dev/null 2>&1
fi
}

function find_usb(){
disks=`cat /proc/partitions | sed 's/  */:/g' | cut -f5 -d: | sed -e /^$/d -e /[1-9]/d -e /^sr0/d -e /loop/d`
#disks=`cat /proc/partitions | sed 's/  */:/g' | cut -f5 -d: | sed -e /^$/d -e /[1-9]/d -e /^sr0/d -e /loop/d -e /^sda/d`
installmedia=""
for disk in $disks; do
 if [ "$disk" != "sda" ]; then
	installmedia=/dev/$disk
 else installemedia=""	
 fi
done
if [ "$installmedia" == "" ]; then
	echo "There is no removable usb device attached to your system"
	exit
else
echo "========================================="
echo "										   "
echo "Removable device is $installmedia        "
echo "										   "
echo "========================================="
fi
}

function usb_message(){
MSG="ATTENTION!!!!!\n\
This script is going to install liveiso to your $installmedia device\n\
This will take some time. So please be patient ..\n\
If you continue, your drive $installmedia will be erased and repartitioned.\n\
All data will be lost.\n\
\n\
\n\
ARE YOU SURE YOU KNOW WHAT YOU'RE DOING?"

dialog --title "Are you sure you want to do this?" \
	--defaultno \
	--yesno "$MSG" 0 0
retval=$?
if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
	exit 0
fi
}

function persistent_message(){
MSG="Do you want to create a persistent file on your drive $installmedia ?\n\
\n\
"
MSG_ENCRYPT="Do you want to encrypt the persistent file ?\n\
\n\
"
	
dialog --title "Create a Persistent file" \
	--defaultno \
	--yesno "$MSG" 0 0
retval=$?
if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
	persistent_file="no"
else	
    persistent_file="yes"
    
    answer="$(eval dialog --title \"Select size in MB\" \
	--stdout \
	--menu \"Select the size of persistent file:\" \
	0 0 0 \
	'100' 'o' \
	'300' 'o' \
	'400' 'o' \
	'500' 'o' \
	'700' 'o' \
	'800' 'o' \
	'1000' 'o' \
	'1500' 'o' \
	'2000' 'o' \
	'2500' 'o' \
	'3000' 'o' \
	'3500' 'o' \
	'3998' 'o')"
	retval=$?
	if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
		persistent_file="no"
	else
		SIZE=$answer
		dialog --title "Encrypt the persistent file" \
	--defaultno \
	--yesno "$MSG_ENCRYPT" 0 0
	retval=$?
		if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
			ENCRYPT="no"
		else	
			ENCRYPT="yes"
		fi
	fi
fi
}
    
function persistent_message_ext3(){
MSG="Do you want to create a persistent file on your drive $installmedia ?\n\
\n\
"
MSG_ENCRYPT="Do you want to encrypt the persistent file ?\n\
\n\
"

dialog --title "Create a Persistent file" \
	--defaultno \
	--yesno "$MSG" 0 0
retval=$?
if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
	persistent_file="no"
else	
    persistent_file="yes"
    
    answer="$(eval dialog --title \"Select size in MB\" \
	--stdout \
	--menu \"Select the size of persistent file:\" \
	0 0 0 \
	'100' 'o' \
	'300' 'o' \
	'400' 'o' \
	'500' 'o' \
	'700' 'o' \
	'800' 'o' \
	'1000' 'o' \
	'1500' 'o' \
	'2000' 'o' \
	'2500' 'o' \
	'3000' 'o' \
	'3500' 'o' \
	'3998' 'o'	\
	'5120' 'o' \
	'6144' 'o' \
	'7168' 'o' \
	'8192' 'o' \
	'9216' 'o' \
	'10240' 'o' \
	'11264' 'o' \
	'12288' 'o' \
	'13312' 'o' \
	'14336' 'o')"
	retval=$?
	if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
		persistent_file="no"
	else
		SIZE=$answer
	dialog --title "Encrypt the persistent file" \
	--defaultno \
	--yesno "$MSG_ENCRYPT" 0 0
	retval=$?
		if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
			ENCRYPT="no"
		else	
			ENCRYPT="yes"
		fi	
	fi 
fi
}

function create_persistent(){
CWD=`pwd`
mkdir -p /mnt/install
mount $installmedia /mnt/install
cd /mnt/install/
FREE=$('df' -k .|tail -n1|awk '{print $4}')
AFTER=$(( $FREE - 1024 * $SIZE ))
if [ $AFTER -gt 0 ]; then
	echo ""
	echo "Creating persistent file 'persistent'. Please wait ..."
	echo ""
		#if [ "$LIVEFSTYPE" == "fixed" ]; then
		#	dd if=/dev/zero of="$NAME" bs=1M count=$SIZE
		#else	
		#	dd if=/dev/zero of="$NAME" bs=1M count=0 seek=$SIZE
		#fi
		#mkfs.ext3 -F -m 0 -L "persistent" "$NAME" && CHECK='OK'
		
		# Create a sparse file (not allocating any space yet):
		dd of=${NAME} bs=1M count=0 seek=$SIZE
		# Setup a loopback device that we can use with cryptsetup:
		LODEV=$(losetup -f)
		losetup $LODEV ${NAME}
        if [ "${ENCRYPT}" = "yes" ]; then
			# Format the loop device with LUKS:
			echo "--- Encrypting the container file with LUKS; enter 'YES' and a passphrase..."
			until cryptsetup -y luksFormat $LODEV ; do
				echo ">>> Did you type two different passphrases?"
				read -p ">>> Press [ENTER] to try again or Ctrl-C to abort ..." REPLY 
			done
			# Unlock the LUKS encrypted container:
			echo "--- Unlocking the LUKS container requires your passphrase again..."
			until cryptsetup luksOpen $LODEV $(basename ${NAME}) ; do
				echo ">>> Did you type an incorrect passphrases?"
				read -p ">>> Press [ENTER] to try again or Ctrl-C to abort ..." REPLY 
			done
			CNTDEV=/dev/mapper/$(basename ${NAME})
			# Now we allocate blocks for the LUKS device. We write encrypted zeroes,
			# so that the file looks randomly filled from the outside.
			# Take care not to write more bytes than the internal size of the container:
			CNTIS=$(( $(lsblk -b -n -o SIZE  $(readlink -f ${CNTDEV})) / 512))
			dd if=/dev/zero of=${CNTDEV} bs=512 count=${CNTIS} || true
		else
			CNTDEV=$LODEV
			# Un-encrypted container files remain sparse.
		fi
		# Format the now available block device with a linux fs:
		mkfs.ext4 ${CNTDEV} && CHECK='OK'
		# Tune the ext4 filesystem:
		tune2fs -m 0 -c 0 -i 0 ${CNTDEV}
		# Don't forget to clean up after ourselves:
		if [ "${ENCRYPT}" = "yes" ]; then
			cryptsetup luksClose $(basename ${NAME})
		fi
		losetup -d ${LODEV} || true
		
	if [ -n "$CHECK" ]; then
		echo ""
		echo "The persistent file $NAME is ready."
		cd $CWD
		sleep 5
		umount /mnt/install
		rmdir /mnt/install
	else
		echo "ERROR: $SCRIPT_NAME was not able to create the persistent file $NAME"
		cd $CWD
		sleep 5		
		umount /mnt/install
		rmdir /mnt/install
		exit 1
	fi
else
  echo "ERROR: There is not enough free space left on your device \
for creating the persistent file $NAME"
	cd $CWD
	sleep 5	
	umount /mnt/install
	rmdir /mnt/install	
  exit 1
fi
}

function filesystem_message(){   
    answer="$(eval dialog --title \"Select filesystem\" \
	--stdout \
	--menu \"Select the filesystem for formatting the usb:\" \
	0 0 0 \
	'vfat' 'o' \
	'ext3' 'o')"
	retval=$?
	if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
		exit 0
	else
		if [ "$answer" == "vfat" ]; then		
			LIVEFS="vfat"
		else
			LIVEFS="ext3"
		fi  
	fi
}

function persistent_file_type(){   
    answer="$(eval dialog --title \"Select persistent file Type\" \
	--stdout \
	--menu \"Select the persistent file type \\n sparse [grow dynamically]  or \\n fixed [allocated space]:\" \
	0 0 0 \
	'fixed' 'o' \
	'sparse' 'o')"
	retval=$?
	if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
		exit 0
	else
		if [ "$answer" == "fixed" ]; then		
			LIVEFSTYPE="fixed"
		else
			LIVEFSTYPE="sparse"
		fi  
	fi
}

    
function install_usb() {
	device=`echo $installmedia | cut -c6-8`
	sectorscount=`cat /sys/block/$device/size`
	sectorsize=`cat /sys/block/$device/queue/hw_sector_size`
	let mediasize=$sectorscount*$sectorsize/1048576 #in MB
	installdevice="/dev/$device"
if [ "$installdevice" == "$installmedia" ]; then #install on whole disk: partition and format media
		#if [ `uname -m` == "x86_64" ] && [ "$iso_arch" == "64" ]; then #EFI/GPT
		if [ "$iso_arch" == "64" ]; then #EFI/GPT
			dd if=/dev/zero of=$installdevice bs=512 count=34 >/dev/null 2>&1
			if [ "$LIVEFS" == "vfat" ]; then
				partitionnumber=1
				installmedia="$installdevice$partitionnumber"
				echo -e "2\nn\n\n\n\n0700\nr\nh\n1 2\nn\n\ny\n\nn\n\nn\nwq\ny\n" | gdisk $installdevice || return $PARTITIONERROR
				#echo -e "2\nn\n\n\n+32M\nef00\nn\n\n\n\n0700\nr\nh\n1 2\nn\n\ny\n\nn\n\nn\nwq\ny\n" | gdisk $installdevice || return $PARTITIONERROR
				#hybrid MBR with BIOS boot partition (1007K) EFI partition (32M) and live partition
				#echo -e "2\nn\n\n\n+32M\nef00\nn\n\n\n\n0700\nn\n128\n\n\nef02\nr\nh\n1 2\nn\n\ny\n\nn\nn\nwq\ny\n" | gdisk $installdevice || return $PARTITIONERROR
				partprobe $installdevice >/dev/null 2>&1; sleep 3
				fat32option="-F 32"
				mkfs.vfat $fat32option -n "$LIVELABEL" $installmedia || return $FORMATERROR
				sleep 3
			else
				efipartition="$installdevice""1"
				installmedia="$installdevice""2"
				#hybrid MBR with BIOS boot partition (1007K) EFI partition (300M) and live partition
				echo -e "2\nn\n\n\n+300M\nef00\nn\n\n\n\n\nr\nh\n1 2\nn\n\ny\n\nn\n\nn\nwq\ny\n" | gdisk $installdevice || return $PARTITIONERROR
				#echo -e "2\nn\n\n\n+32M\nef00\nn\n\n\n\n\nn\n128\n\n\nef02\nr\nh\n1 2\nn\n\ny\n\nn\nn\nwq\ny\n" | gdisk $installdevice || return $PARTITIONERROR
				# set the linux partition bootable
				sgdisk -p -A 2:set:2 $installdevice
				# confirm it was indeed set correctly
				sgdisk -p -A 2:show $installdevice
				partprobe $installdevice; sleep 3
				echo "*** Formating EFI partition $efipartition ..."
				mkfs.vfat -n "EFI" $efipartition || return $FORMATERROR
				echo "*** Formating system partition $installmedia ..."
				mkfs.ext3 -F -L "$LIVELABEL" $installmedia || return $FORMATERROR
				sleep 3
			fi
		else #BIOS/MBR
			partitionnumber=1
			installmedia="$installdevice$partitionnumber"
			if (( $mediasize < 2048 ))
			then heads=128; sectors=32
			else heads=255; sectors=63
			fi
			mkdiskimage $installdevice 1 $heads $sectors || return $PARTITIONERROR
			dd if=/dev/zero of=$installdevice bs=1 seek=446 count=64 >/dev/null 2>&1
			if [ "$LIVEFS" = "vfat" ]; then
				#echo -e ',0\n,0\n,0\n,,83,*' | sfdisk $installdevice || return $PARTITIONERROR
				#echo -e ',0\n,0\n,0\n,,b,*' | sfdisk $installdevice || return $PARTITIONERROR
				echo -e ',,b,*' | sfdisk $installdevice || return $PARTITIONERROR
				partprobe $installdevice; sleep 3
				fat32option="-F 32"
				mkfs.vfat $fat32option -n "$LIVELABEL" $installmedia || return $FORMATERROR
			else
				echo -e ',,83,*' | sfdisk $installdevice || return $PARTITIONERROR
				partprobe $installdevice; sleep 3
				mkfs.ext3 -L "$LIVELABEL" $installmedia || return $FORMATERROR
			fi
			sleep 3
		fi

else #install on partition: filesystem check and format if needed
		partitionnumber=`echo $installmedia | cut -c9-`
		mkdir -p /mnt/tmp
		if mount $installmedia /mnt/tmp >/dev/null 2>&1; then
			sleep 1
			umount /mnt/tmp
			fsck -fy $installmedia >/dev/null 2>&1
		else #format partition
			if fdisk -l $installdevice 2>/dev/null | grep -q 'GPT\|gpt'; then
				partitiontype=`gdisk -l $installdevice | grep "^  *$partitionnumber " | sed 's/  */:/g' | cut -f7 -d:`
			else
				partitiontype=`fdisk -l $installdevice 2>/dev/null | grep "^$installmedia " | sed -e 's/\*//' -e 's/  */:/g' | cut -f5 -d:`
			fi
			case $partitiontype in
			83|8300) 
				mkfs.ext3 -L "$LIVELABEL" $installmedia || return $FORMATERROR
				;;
			*)
				partition=`echo $installmedia | cut -c6-`
				size=`cat /proc/partitions | grep " $partition$" | sed 's/  */:/g' | cut -f4 -d:`
				let size=$size/1024
				if (( $size > 1024 )); then
					fat32option="-F 32"
				fi
				mkfs.fat $fat32option -n "$LIVELABEL" $installmedia || return $FORMATERROR
			esac
			sleep 3
		fi
fi

#live system files copy
echo ""
echo ""
echo "Copying live system on $installmedia"
echo ""
echo ""
	#if [ `uname -m` == "x86_64" ] && [ "$iso_arch" == "64" ]; then #EFI/GPT
#	if  [ "$iso_arch" == "64" ]; then #EFI/GPT
#		efipartition="$installdevice"`gdisk -l $installdevice 2>/dev/null | grep " EF00 " | sed 's/  */:/g' | cut -f2 -d:`
#		if [ ! -z "$efipartition" ] && [ "$efipartition" != "$installmedia" ]; then
#			mkdir -p /mnt/tmp
#			if mount $efipartition /mnt/tmp >/dev/null 2>&1; then
#				sleep 1
#				umount /mnt/tmp
#			else
#				mount | grep -q "^$installmedia .* vfat "
#				mkfs.fat -n  "efi" $efipartition || return $FORMATERROR
#			fi
#			#mkdir -p /mnt/efi
#			#mount $efipartition /mnt/efi
#			#cp -r $livedirectory/EFI /mnt/efi/
#			#umount /mnt/efi
#			#rmdir /mnt/efi
#		fi
#	fi
	
	mkdir -p /mnt/install
	mount $installmedia /mnt/install
	cp -r $livedirectory/boot /mnt/install/
	#if [ `uname -m` == "x86_64" ] && [ "$iso_arch" == "64" ]; then #EFI/GPT
	if  [ "$iso_arch" == "64" ]; then #EFI/GPT
	    if [ "$LIVEFS" = "vfat" ]; then
			cp -r $livedirectory/EFI /mnt/install/
			cp $livedirectory/efi.img /mnt/install/
		else
			echo "*** Installing EFI on $efipartition ..."
			mkdir -p /mnt/efi
			mount $efipartition /mnt/efi; sleep 1
			cp -r $livedirectory/EFI /mnt/efi/
			cp $livedirectory/efi.img /mnt/efi
			umount /mnt/efi
			rmdir /mnt/efi
		fi
	fi
	if fdisk -l $installdevice 2>/dev/null | grep -q "^$installmedia "; then #legacy / CSM (Compatibility Support Module) boot, if $installmedia present in MBR (or hybrid MBR)
		sfdisk --force $installdevice -A $partitionnumber 2>/dev/null
		if mount | grep -q "^$installmedia .* vfat "; then #FAT32
			umount /mnt/install
			# Use syslinux to make the USB device bootable:
			echo "--- Making the USB drive '$installdevice' bootable using syslinux..."
			syslinux -d /boot/syslinux $installmedia || return $BOOTERROR
			cat /usr/share/syslinux/mbr.bin > $installdevice
		else #ext3
			#mv /mnt/install/boot/syslinux /mnt/install/boot/extlinux
			#mv /mnt/install/boot/extlinux/syslinux.cfg /mnt/install/boot/extlinux/extlinux.conf
			#rm -f /mnt/install/boot/extlinux/isolinux.*
			#rm -f /mnt/install/boot/extlinux/boot.catalog
			#/sbin/extlinux --install /mnt/install/boot/extlinux
			# Use extlinux to make the USB device bootable:
			echo "--- Making the USB drive '$installdevice' bootable using extlinux..."
			extlinux -i /mnt/install/boot/syslinux || return $BOOTERROR
			umount /mnt/install
			if fdisk -l $installdevice 2>/dev/null | grep -q 'GPT\|gpt'; then
				cat /usr/share/syslinux/gptmbr.bin > $installdevice
			else
				cat /usr/share/syslinux/mbr.bin > $installdevice
			fi
		fi
	else
		umount /mnt/install
	fi
	umount /mnt/install 2>/dev/null
	sleep 2
	rmdir /mnt/install
	umount $livedirectory
	rmdir $livedirectory
	
	return 0
}

action=$1
case $action in
"--usb")
    isoname=$2
    installmedia=$3
    if [ "$installmedia" == "" ] || [ "$installmedia" == NULL ]; then
    		echo "`basename $0` --usb iso_name device"
		exit $CMDERROR
	fi	
    check_root
if  check_if_file_iso_exists $isoname ; then
	flag=*
	for n in $installmedia$flag ; do umount $n > /dev/null 2>&1; done
	check_device $installmedia
	#find_usb
	usb_message
	create_link_for_other_distros
	ISODIR=$(mktemp -d)
	LODEVISO=$(losetup -f)
	losetup $LODEVISO $isoname
	mount $LODEVISO $ISODIR > /dev/null 2>&1
	#mount -o loop $isoname $ISODIR > /dev/null 2>&1
	livedirectory=$ISODIR
    if [ -f "$isoname" ] && [ -b "$installmedia" ]; then
		livesystemsize=`du -s -m $livedirectory | sed 's/\t.*//'`
		device=`echo $installmedia | cut -c6-8`
		partition=`echo $installmedia | cut -c6-`
		sectorscount=`cat /sys/block/$device/subsystem/$partition/size`
		sectorsize=`cat /sys/block/$device/queue/hw_sector_size`
		let destinationsize=$sectorscount*$sectorsize/1048576
		if (( $livesystemsize > $destinationsize)); then 
			echo "error: insufficant space on device '$installmedia'"
			umount $ISODIR
			rmdir $ISODIR
			losetup -d $LODEVISO || true
			exit $INSUFFICIENTSPACE
		else
			filesystem_message
			if [ "$LIVEFS" == "vfat" ]; then
				#persistent_file_type
				persistent_message
			else
				#persistent_file_type
				persistent_message_ext3
			fi
			install_usb $livedirectory $installmedia
			losetup -d $LODEVISO || true
			if [ "$persistent_file" == "yes" ]; then
			 create_persistent
			fi	
			exit $!
		fi
	else
		umount $ISODIR
		rmdir $ISODIR
		losetup -d $LODEVISO || true
		echo "`basename $0` --usb iso_name device"
		exit $CMDERROR
	fi
		cd ~/
		sleep 5
		umount  /tmp/tmp.* > /dev/null 2>&1
		rm -rf /tmp/tmp.*
fi		
;;

"--persistent")
	iso_arch=$2
	installmedia=$3
	check_device $installmedia
if  [ "$iso_arch" == "32" ] || [ "$iso_arch" == "64" ]; then
	#find_usb
	device=`echo $installmedia | cut -c6-8`
	sectorscount=`cat /sys/block/$device/size`
	sectorsize=`cat /sys/block/$device/queue/hw_sector_size`
	let mediasize=$sectorscount*$sectorsize/1048576 #in MB
	installdevice="/dev/$device"
	#if [ `uname -m` == "x86_64" ] && [ "$iso_arch" == "64" ]; then #EFI/GPT
	if [ "$iso_arch" == "64" ]; then #EFI/GPT
		if mount $installdevice"2" /mnt/tmp >/dev/null 2>&1; then
		    sleep 1
		    umount /mnt/tmp
		    partitionnumber=2
			installmedia="$installdevice$partitionnumber"
			#persistent_file_type
			echo $installmedia
			persistent_message_ext3
		else	
			partitionnumber=1
			installmedia="$installdevice$partitionnumber"
			#persistent_file_type
			echo $installmedia			
			persistent_message
		fi
	else #BIOS/MBR
			partitionnumber=1
			installmedia="$installdevice$partitionnumber"
		if mount $installmedia /mnt/tmp >/dev/null 2>&1; then
			#persistent_file_type
			echo $installmedia
			if mount | grep -q "^$installmedia .* vfat "; then
			    persistent_message
			else		
				persistent_message_ext3
			fi
			sleep 1
			umount /mnt/tmp	
		fi	
	fi		
		if [ "$persistent_file" == "yes" ]; then
			 create_persistent
		fi 
			exit $!
else
		echo "`basename $0` --persistent 32|64 device"
		exit $CMDERROR
fi
;;
"--version")
	version
    exit 0
	;;
"--help")
usage
exit 0
;;	
	
*)	echo "`basename $0` --persistent 32|64 device"
	echo "`basename $0` --usb isoname device"
	exit $CMDERROR
	;;
esac
