# luks-installer
##To put a MX Linux distro on encrypted partitions.

source and release thread: http://antix.freeforums.org/custom-install-multiple-partitions-optional-encryption-t3579.html

Install Script for Multiple Partitions (with optional Encryption)

This script is for anyone who wishes to run a system with a separate /boot /usr or /var which is not an option with the MEPIS Installer. It will move any system from single or multiple partitions to single or multiple partitions (so would also be useful for moving a system to a new hard drive). The script is designed to be run from a terminal on a LIVE USB / CD only & will not run on an installed system or outside of a terminal.

It is also possible to optionally create LUKS Encrypted Partitions for both HOME & ROOT with the option to create a keyfile for HOME (so you only enter one password while booting). Creating Encrypted Partitions will destroy any data currently held there so please backup any data there you intend to keep. Before creation of the LUKS Containers there are 2 options to fill the partition either with zeros (very quick to finish) or with random data (slower to finish but giving better encryption). With both methods progress % or size completed is displayed. ROOT & HOME can use the same or different methods for this wiping.

Both Legacy GRUB & GRUB2 are supported & the script takes care of updating fstab / menu.lst or grub.cfg / crypttab as appropriate.

The script should be reasonably foolproof with sanity checks for the data being copied & comparisons of source files & destination partition sizes before copying begins. Progress of the data copying is also displayed.

As well as moving a system to a different disk or to multiple partitions it is also possible to move /boot /usr /var (singly or any combination thereof) out of the root of an existing system (or back into root). For a brand new installation of Antix install the entire system into the partition which will become /usr for the quickest system move.

Supported file system creation = ext2 / ext3 / ext4 / xfs / minix

Example script configuration for this method:

/##### USER DEFINABLE VALUES ###########################
OLDBOOT=/dev/sda7
OLDROOT=/dev/sda7
OLDUSR=/dev/sda7
OLDVAR=/dev/sda7
OLDHOME=/dev/sda7
NEWBOOT=/dev/sda5
NEWROOT=/dev/sda6
NEWUSR=/dev/sda7
NEWVAR=/dev/sda8
NEWHOME=/dev/sda9
/#MAPPERS - used for Encrypted Partitions only ##################
MAPPERHOME=home
MAPPERROOT=root
BOOTFS=ext2
ROOTFS=ext4
USRFS=ext4
VARFS=ext4
HOMEFS=ext4
/#DESTINATION DISK (for /etc/fstab) #########################
DISK=/dev/sda
/#VERSION (needed for Legacy GRUB only) #####################
VERSION=/etc/antix-version
/##################################################

Calculating disk space & installing dependency pv:
Image

Confirming Source & Destination Partitions:
Image

Choosing Standard or Encrypted HOME & ROOT:
Image

Copying data with progress shown:
Image
Image

Updating fstab / menu.lst & Legacy GRUB
Image

Final screen once system moving is complete:
Image

Optional Encrypted Partition screens

Create LUKS partition confirmation:
Image

Checking for Bad Blocks:
Image

Choosing wipe method (Zeros or Random Data):
Image

Wiping with Random data
Image

Creating LUKS container (over zeros)
Image

Updating fstab / crypttab / menu.lst / adding crypt modules & creating keyfile:
Image

I have used this script to move Antix on my own encrypted systems without any problems & have tested it extensively in Virtualbox, but perhaps also test your particular setup in Virtualbox first to become familiar with the script's workings. HOME is only formatted in the case of creating new Encrypted Partitions. The partitions for BOOT ROOT USR & VAR are formatted whenever they move to their own partitions.

The following dependencies are installed by the script as & when required:

dialog (already part of AntiX)
pv (for copying progress)
cryptsetup (for mounting / creating LUKS encrypted partitions)
dc3dd (for faster zeroing of LUKS partitions & showing % completed)
dcfldd (so progress is shown while filling a LUKS partition with random data)
