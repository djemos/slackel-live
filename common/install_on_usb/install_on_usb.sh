#!/bin/bash
# Gettext internationalization

#"BASED ON CODE OF BUILD_SLACKWARE-LIVE.SH FROM linux-nomad"
AUTHOR='Dimitris Tzemos - djemos@slackel.gr '
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
SCRIPT_NAME="$(basename $0)"
NAME="persistent"
SVER=14.1

function check_root(){
# make sure I am root
if [ `id -u` != "0" ]; then
	echo "ERROR: You need to be root to run $SCRIPT_NAME"
	echo "The install_on_usb_uefi.sh script needs direct access to your boot device."
	echo "Use sudo or kdesudo or similar wrapper to execute this."
	exit 1
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
	isonamef="${isoname%%-*}"
	isonamef="${isonamef##*/}"

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
	echo "Creating persistent file 'persistent'. Please wait ..."
	echo ""
	dd if=/dev/zero of="$NAME" bs=1M count=$SIZE
	mkfs.ext3 -F -m 0 -L "persistent" "$NAME" && CHECK='OK'
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
    
function install_usb() {
	device=`echo $installmedia | cut -c6-8`
	sectorscount=`cat /sys/block/$device/size`
	sectorsize=`cat /sys/block/$device/queue/hw_sector_size`
	let mediasize=$sectorscount*$sectorsize/1048576 #in MB
	installdevice="/dev/$device"
if [ "$installdevice" == "$installmedia" ]; then #install on whole disk: partition and format media
		#if [ `uname -m` == "x86_64" ] && [ "$iso_arch" == "64" ]; then #EFI/GPT
		if [ "$iso_arch" == "64" ]; then #EFI/GPT
			partitionnumber=1
			installmedia="$installdevice$partitionnumber"
			dd if=/dev/zero of=$installdevice bs=512 count=34 >/dev/null 2>&1
			#echo -e "2\nn\n\n\n+32M\nef00\nn\n\n\n\n0700\nr\nh\n1 2\nn\n\ny\n\nn\n\nn\nwq\ny\n" | gdisk $installdevice || return $PARTITIONERROR
			echo -e "2\nn\n\n\n\n0700\nr\nh\n1 2\nn\n\ny\n\nn\n\nn\nwq\ny\n" | gdisk $installdevice || return $PARTITIONERROR
			#hybrid MBR with BIOS boot partition (1007K) EFI partition (32M) and live partition
			#echo -e "2\nn\n\n\n+32M\nef00\nn\n\n\n\n0700\nn\n128\n\n\nef02\nr\nh\n1 2\nn\n\ny\n\nn\nn\nwq\ny\n" | gdisk $installdevice || return $PARTITIONERROR
			partprobe $installdevice >/dev/null 2>&1; sleep 3
		#	mkfs.fat -n "efi"  $installdevice"1" || return $FORMATERROR
			#mkfs.ext3 -L "$LIVELABEL" $installmedia || return $FORMATERROR
			fat32option="-F 32"
			mkfs.vfat $fat32option -n "$LIVELABEL" $installmedia || return $FORMATERROR
		else #BIOS/MBR
			partitionnumber=4
			installmedia="$installdevice$partitionnumber"
			if (( $mediasize < 2048 ))
			then heads=128; sectors=32
			else heads=255; sectors=63
			fi
			mkdiskimage $installdevice 1 $heads $sectors || return $PARTITIONERROR
			dd if=/dev/zero of=$installdevice bs=1 seek=446 count=64 >/dev/null 2>&1
			#echo -e ',0\n,0\n,0\n,,83,*' | sfdisk $installdevice || return $PARTITIONERROR
			echo -e ',0\n,0\n,0\n,,b,*' | sfdisk $installdevice || return $PARTITIONERROR
			partprobe $installdevice; sleep 3
			#mkfs.ext3 -L "$LIVELABEL" $installmedia || return $FORMATERROR
			fat32option="-F 32"
			mkfs.vfat $fat32option -n "$LIVELABEL" $installmedia || return $FORMATERROR
		fi
		sleep 3
	
else #install on partition: filesystem check and format if needed
		partitionnumber=`echo $installmedia | cut -c9-`
		mkdir -p /mnt/tmp
		if mount $installmedia /mnt/tmp >/dev/null 2>&1; then
			sleep 1
			umount /mnt/tmp
			fsck -fy $installmedia >/dev/null 2>&1
		else #format partition
			if fdisk -l $installdevice 2>/dev/null | grep -q GPT; then
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
		cp -r $livedirectory/EFI /mnt/install/
		cp $livedirectory/efi.img /mnt/install/
	fi
	if fdisk -l $installdevice 2>/dev/null | grep -q "^$installmedia "; then #legacy / CSM (Compatibility Support Module) boot, if $installmedia present in MBR (or hybrid MBR)
		sfdisk --force $installdevice -A $partitionnumber 2>/dev/null
		if mount | grep -q "^$installmedia .* vfat "; then #FAT32
			umount /mnt/install
			syslinux -d /boot/syslinux $installmedia || return $BOOTERROR
		else #Ext3 
			extlinux -i /mnt/install/boot/syslinux || return $BOOTERROR
			umount /mnt/install
		fi
		cat /usr/share/syslinux/mbr.bin > $installdevice
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
	check_device $installmedia
	#find_usb
	usb_message
	ISODIR=$(mktemp -d)
	mount -o loop $isoname $ISODIR > /dev/null 2>&1
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
			exit $INSUFFICIENTSPACE
		else
			persistent_message
			install_usb $livedirectory $installmedia
			if [ "$persistent_file" == "yes" ]; then
			 create_persistent
			fi
			exit $!
		fi
	else
		umount $ISODIR
		rmdir $ISODIR
		echo "`basename $0` --usb iso_name device"
		exit $CMDERROR
	fi
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
			partitionnumber=1
			installmedia="$installdevice$partitionnumber"
	else #BIOS/MBR
			partitionnumber=4
			installmedia="$installdevice$partitionnumber"
	fi		
        echo $installmedia
		persistent_message
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
