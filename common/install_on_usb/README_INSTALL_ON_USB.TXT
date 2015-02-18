INSTALLING THE ISO IMAGE TO A USB KEY
=====================================

The install_on_usb.sh script is used to install the iso image to a usb
key using the iso image itself.

You can mount the iso image to a directory e.g.: /tmp/iso and enter
the boot directory within the mountpoint, e.g.: cd /tmp/iso/boot
and execute the script from there:

  sudo mkdir /tmp/iso
  sudo mount -o loop path_to_iso_image /tmp/iso
  cd /tmp/iso/boot
  sudo sh install_on_usb.sh --usb path_to_iso_image device

device can be something like /dev/sdb or /dev/sdc according to how
many usb keys are plugged in your system.
There is no chance to install to your hard disk /dev/sda or /dev/hda.
The script will just exit in such a case.

So, you have to specify the path to the iso image and device. The script
will ask the user to confirm the device specified and it will also
optionally create a persistent ext3 file.

If the user did not do so on first installation, then he can create a
persistent file using the --persistent option. There is now no need to
specify the path to the iso because Slackel Live is already installed to
the usb key. However, you do need to specify the architecture, because
this affects the location of the persistent file:

  sudo sh install_on_usb.sh --persistent 32|64 device

For example, for a 64-bit iso installed on /dev/sdc, you should
run the following command to create persistence:

  sudo sh install_on_usb.sh --persistent 64 /dev/sdc


Typing:
 
  sh install_on_usb.sh --help

will output the following help message:

  install_on_usb.sh [-h/--help] [-v/--version]
  -h, --help: this usage message
  -v, --version: the version author and licence

  install_on_usb.sh --usb isoname device
  install_on_usb.sh --persistent 32|64 device

  -> --usb option installs syslinux on a USB key using an ISO (specify
       path to image and device)
  -> The script will ask user to confirm the device specified
  -> It will also optionally create a persistent ext3 file.

  -> --persistent option creates a persistent ext3 file after
     installation, if user did not do so then
  -> specify architecture and device
  -> No need to specify path to iso because Slackel Live is already
     installed
