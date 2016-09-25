#!/bin/sh
# -----------------------------------------------------------------------------
# Copyright 2012 Stuart Cardall <linuxisfreedom at lavabit dot com>
# All rights reserved.
#
#   Permission to use, copy, modify, and distribute this software for
#   any purpose with or without fee is hereby granted, provided that
#   the above copyright notice and this permission notice appear in all
#   copies.
#

# release thread : 
# http://antix.freeforums.org/custom-install-multiple-partitions-optional-encryption-t3579.html
# filename: antix-move-1     
# github fork: https://github.com/mxu3/luks-installer/edit/master/luks-tool.sh



# A MX Linux (debian) distro is very easy to handle: From a bootable USB thumbdrive F5 bootmenu you can quickly
# make a "frugal install" onto harddisk (to gain speed) without even touching the hd boot business.
# This will copy the main 1.5 GB "linuxfs" compressed file and some other files into a single subdirectory.
# Use persistence at the bootmenu to retain all modified data. Remaster and produce a (cleansed) snapshot copy of your custom MX 
# as a bootable .ISO hybrid image file. Use the "MX-tools" GUI to do it within 5 minutes (10 minutes with USB flashdrive).
# This tool "antix-move-1" adds encryption features to make your data safe and private.
#
#







#   THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
#   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.
#
##### System Moving Script for  ########################################
##### Normal & Encrypted Partitions v1.0 ###############################
##### Designed to be run from a LIVE USB / CD ##########################
##### USER DEFINABLE VALUES ############################################
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
#MAPPERS - set for Encrypted Partitions only ###########################
MAPPERHOME=home
MAPPERROOT=root
BOOTFS=ext2
ROOTFS=ext4
USRFS=ext4
VARFS=ext4
HOMEFS=ext4
#DESTINATION DISK (for /etc/fstab) #####################################
DISK=/dev/sda
#VERSION (needed for Legacy GRUB only) #################################
VERSION=/etc/antix-version
########################################################################

#Exit on most errors
set -e
#set -x

[ -t 0 ] && [ -t 1 ] || { zenity --warning --text="${0}: this script must be run from a terminal." ; exit 1 ;}

if [ "$(id -un)" != "root" ]; then
  echo "You must be superuser to use this script" >&2
  exit 1
fi

if ! cat /etc/passwd|grep "demo" 1>/dev/null; then
  echo "This script needs to be run from a Live CD / USB."
  exit 0
fi

if [ "$NEWHOME" = "$NEWROOT" ]; then
   read -p "Both ROOT & HOME are set to $NEWROOT ??? (y/n): " ANSWER
      case $ANSWER in
         y | yes)
         echo "continuing............."
         ;;
         *)
         exit 1
         ;;
      esac
fi      

#check partitions exist
PARTCHECK="$NEWBOOT $NEWROOT $NEWUSR $NEWVAR $NEWHOME $OLDBOOT $OLDROOT $OLDUSR $OLDVAR $OLDHOME"
for PART in $PARTCHECK
do   
   if ! fdisk -l | grep $PART 1> /dev/null; then
      echo "\nPartion $PART does not exist on this system." \
      "\n\nPlease correct USER DEFINABLE values & rerun this script."
      exit 0      
   fi
done

#check partitions have sane values
#NEWUSR can be within OLDROOT - see line 528 for faster install of a new system
for PART in "BOOT $NEWBOOT" "ROOT $NEWROOT" "VAR $NEWVAR" "HOME $NEWHOME"
do   
   if [ "$2" = "$OLDROOT" ]; then
      echo "\n$1 is set to the same partition as OLDROOT ($OLDROOT)." \
      "\n\nPlease correct USER DEFINABLE values & rerun this script."
      exit 0      
   fi
done

#create DESTINATION & SOURCE mount points on LIVE System
MNTPOINTS="/mnt/newboot /mnt/newroot /mnt/newvar /mnt/newusr /mnt/newhome /mnt/oldboot /mnt/oldroot /mnt/oldusr /mnt/oldvar /mnt/oldhome"
for POINTS in $MNTPOINTS
do   
   if [ ! -d "$POINTS" ]; then
   mkdir $POINTS
   fi
done

#mount SOURCE partition(s) & calculate used disk space
if blkid $OLDROOT|grep "crypto_LUKS" 1> /dev/null; then
   if [ ! -x "$(which cryptsetup)" ]; then
      echo "Installing cryptsetup to mount Encrypted source root $OLDROOT"
      apt-get update && apt-get install -y cryptsetup
   fi
   if cryptsetup status oldroot|grep "inactive" 1> /dev/null; then
      cryptsetup luksOpen $OLDROOT oldroot
   fi
   echo "mounting Encrypted $OLDROOT on /mnt/oldroot"
   mountpoint -q /mnt/oldroot || mount /dev/mapper/oldroot /mnt/oldroot
else   
   echo "mounting $OLDROOT on /mnt/oldroot"
   mountpoint -q /mnt/oldroot || mount $OLDROOT /mnt/oldroot
fi
#check OLDROOT is a root filesystem
MOUNTPOINTS="home proc mnt opt selinux sys boot usr var"
DIRCHECK=0
for DIR in $MOUNTPOINTS
do
   if [ -d "/mnt/oldroot/$DIR" ]; then
      DIRCHECK=$((DIRCHECK +1))
   fi
done
if [ $DIRCHECK -le 7 ]; then
   echo "OLDROOT ($OLDROOT) does not appear to be a root filesystem" \
   "\n\nPlease check USER DEFINED settings & re-run this script."
   umount /mnt/oldroot
   exit 0
fi
echo "Calculating used disk space on SOURCE file systems - please wait......"
ROOT2CP=$(echo `df /mnt/oldroot` | awk '{print $10}')

if [ "$OLDBOOT" != "$OLDROOT" ]; then
   echo "mounting $OLDBOOT on /mnt/oldboot"
   mountpoint -q /mnt/oldboot || mount $OLDBOOT /mnt/oldboot
   BOOT2CP=$(echo `df /mnt/oldboot` | awk '{print $10}')
else
   BOOT2CP=$(echo `du /mnt/oldroot/boot` | awk '{print $(NF-1)}')
fi
if [ "$OLDUSR" != "$OLDROOT" ]; then
   echo "mounting $OLDUSR on /mnt/oldusr"
   mountpoint -q /mnt/oldusr || mount $OLDUSR /mnt/oldusr
   USR2CP=$(echo `df /mnt/oldusr` | awk '{print $10}')
else
   USR2CP=$(echo `du /mnt/oldroot/usr` | awk '{print $(NF-1)}')
fi
if [ "$OLDVAR" != "$OLDROOT" ]; then
   echo "mounting $OLDVAR on /mnt/oldvar"
   mountpoint -q /mnt/oldvar || mount $OLDVAR /mnt/oldvar
   VAR2CP=$(echo `df /mnt/oldvar` | awk '{print $10}')
else
   VAR2CP=$(echo `du /mnt/oldroot/var` | awk '{print $(NF-1)}')
fi
if [ "$OLDHOME" != "$OLDROOT" ]; then
   if blkid $OLDHOME|grep "crypto_LUKS" 1> /dev/null; then
      if [ ! -x "$(which cryptsetup)" ]; then
      echo "Installing cryptsetup to mount Encrypted source /home $OLDHOME"
      apt-get install -y cryptsetup
      fi
      if cryptsetup status oldhome|grep "inactive" 1> /dev/null; then
         cryptsetup luksOpen $OLDHOME oldhome
      fi
      echo "mounting Encrypted $OLDHOME on /mnt/oldhome"
      mountpoint -q /mnt/oldhome || mount /dev/mapper/oldhome /mnt/oldhome
   else
   echo "mounting $OLDHOME on /mnt/oldhome"
   mountpoint -q /mnt/oldhome || mount $OLDHOME /mnt/oldhome
   fi
   HOME2CP=$(echo `df /mnt/oldhome` | awk '{print $10}')
else
   HOME2CP=$(echo `du /mnt/oldroot/home` | awk '{print $(NF-1)}')
fi

#get DESTINATION available disk space
echo "Calculating available disk space on DESTINATION file systems - please wait......"
ROOTX=$(sfdisk -l /dev/sda 2>/dev/null | grep $NEWROOT | awk '{print $5}')
if [ "$NEWBOOT" != "$NEWROOT" ]; then
   BOOTX=$(sfdisk -l /dev/sda 2>/dev/null | grep $NEWBOOT | awk '{print $5}')
   BOOTX=$(echo $BOOTX | tr -cd [:digit:])
   if [ "$OLDBOOT" = "$OLDROOT" ]; then
      ROOT2CP=$(($ROOT2CP-$BOOT2CP))
   fi
elif [ "$OLDBOOT" != "$OLDROOT" ]; then
   ROOT2CP=$(($ROOT2CP+$BOOT2CP))
fi
if [ "$NEWUSR" != "$NEWROOT" ]; then
   USRX=$(sfdisk -l /dev/sda 2>/dev/null | grep $NEWUSR | awk '{print $5}')
   USRX=$(echo $USRX | tr -cd [:digit:])
   if [ "$OLDUSR" = "$OLDROOT" ]; then
      ROOT2CP=$(($ROOT2CP-$USR2CP))
   fi
elif [ "$OLDUSR" != "$OLDROOT" ]; then
   ROOT2CP=$(($ROOT2CP+$USR2CP))
fi
if [ "$NEWVAR" != "$NEWROOT" ]; then
   VARX=$(sfdisk -l /dev/sda 2>/dev/null | grep $NEWVAR | awk '{print $5}')
   VARX=$(echo $VARX | tr -cd [:digit:])
   if [ "$OLDVAR" = "$OLDROOT" ]; then
      ROOT2CP=$(($ROOT2CP-$VAR2CP))
   fi
elif [ "$OLDVAR" != "$OLDROOT" ]; then
   ROOT2CP=$(($ROOT2CP+$VAR2CP))
fi
if [ "$NEWHOME" != "$NEWROOT" ]; then
   HOMEX=$(sfdisk -l /dev/sda 2>/dev/null | grep $NEWHOME | awk '{print $5}')
   HOMEX=$(echo $HOMEX | tr -cd [:digit:])
   if [ "$OLDHOME" = "$OLDROOT" ]; then
      ROOT2CP=$(($ROOT2CP-$HOME2CP))
   fi
elif [ "$OLDHOME" != "$OLDROOT" ]; then
   ROOT2CP=$(($ROOT2CP+$HOME2CP))
fi
#compare source & destination sizes
for SIZECHECK in "ROOT $ROOT2CP $ROOTX" "BOOT $BOOT2CP $BOOTX" "USR $USR2CP $USRX" "VAR $VAR2CP $VARX" "HOME $HOME2CP $HOMEX"
do
   set -- $SIZECHECK
   if [ -n "$3" ]; then
      echo "$1: OLD = $2 (used) NEW = $3 (available)"
      if [ "$2" -gt "$3" ]; then
         echo "\nDESTINATION: $1 is smaller than SOURCE: $1
         \nPlease correct User Defined Values & rerun this script."
         exit 0
      fi
   fi
done

#install dependencies normal install
DEBCHECK="dialog pv"
for DEB in $DEBCHECK
do
   if [ ! -x "$(which $DEB)" ]; then
         echo "This Script requires $DEB - installing......."
         apt-get update && apt-get install $DEB
   fi
done

#confirm installation partitions
dialog --title "Installation Partitions" \
       --yesno "\nThe system will be moved FROM & TO the following partitions: \n
   \nFROM: OLDBOOT ($OLDBOOT)  TO: NEWBOOT ($NEWBOOT)\nFROM: OLDROOT ($OLDROOT)  TO: NEWROOT ($NEWROOT)
   \nFROM: OLDUSR  ($OLDUSR)  TO: NEWUSR ($NEWUSR)\nFROM: OLDVAR  ($OLDVAR)  TO: NEWVAR ($NEWVAR)
   \nFROM: OLDHOME ($OLDHOME)  TO: NEWHOME ($NEWHOME)" 14 57
if [ $? = 1 ]; then
   exit 0   
fi
             
dialog --title "Move installation to Standard or Encrypted Partitions" \
      --menu "Choose one of the following or press <Cancel> to exit" 10 70 2 \
   "1" "Move installation to Standard Partitions" \
   "2" "Move installation to ENCRYPTED HOME & ROOT Partitions" 2>/tmp/ans
if [ $? = 1 ]; then
   rm -f /tmp/ans
   clear
   exit 0
fi

R="`cat /tmp/ans`"
rm -f /tmp/ans
clear

#normal install - mount / & /home
if [ "$R" = "1" ]; then
   if [ "$OLDROOT" != "$NEWROOT" ]; then
      if mount|grep "$NEWROOT" 1> /dev/null; then
         echo "unmounting $NEWROOT"; umount $NEWROOT
      fi
      echo "formatting DESTINATION partition /"
      mkfs.$ROOTFS -q $NEWROOT
   fi
   echo "mounting "$NEWROOT" on /mnt/newroot"
   mountpoint -q /mnt/newroot || mount $NEWROOT /mnt/newroot
   if blkid $NEWHOME|grep "crypto_LUKS" 1> /dev/null; then
      echo "\n$NEWHOME is a LUKS Encrypted Partition \
        \nRe-run this script & chooose installation to Encrypted Partitions."
      exit 0
   else
      if [ "$NEWHOME" != "$NEWROOT" ]; then
         echo "mounting "$NEWHOME" on /mnt/newhome"
         mountpoint -q /mnt/newhome || mount $NEWHOME /mnt/newhome
      fi
   fi
   
#luks encrypted install - mount mappers for / & home
elif [ "$R" = "2" ]; then
   if [ "$NEWBOOT" = "$NEWROOT" ]; then
      echo "BOOT must be on a separate UNENCRYPTED partition
      \nPlease correct USER DEFINED settings & rerun this script"
      exit 0
   fi
   if [ "$OLDROOT" = "$NEWROOT" ]; then
      echo "Cannot Encrypt a ROOT system ($NEWROOT) that is not moving - exiting."
      exit 0
   fi
   if [ ! -x "$(which cryptsetup)" ]; then
      echo "Installing Cryptsetup into LIVE SYSTEM"
      apt-get update && apt-get install -y cryptsetup
   fi   
   ENCRYPTDRIVES="$NEWROOT $NEWHOME"
   for EDRIVE in $ENCRYPTDRIVES
   do
      if ! blkid $EDRIVE|grep "crypto_LUKS" 1> /dev/null; then
            #create LUKS partition if not existing
            dialog --title "Create Encrypted LUKS Partion" \
            --yesno "\nCreate new Encrypted Partition on \n\n $EDRIVE ?" 8 38
            if [ $? = 1 ]; then
               exit 0   
            else
               if mount|grep "$EDRIVE" 1> /dev/null; then
                  echo "unmounting $EDRIVE"; umount $EDRIVE
               fi
               /sbin/badblocks -c 10240 -s -w -t random -v $EDRIVE
               dialog --title "Fill Partition with ZEROS or RANDOM Data" \
               --menu "Choose one of the following or press <Cancel> to exit" 10 75 2 \
               "1" "Fill $EDRIVE with ZEROS (Older machines / Celeron processors)" \
               "2" "Fill $EDRIVE with RANDOM DATA (Slower - Better Encryption)" 2>/tmp/ans
               EFILL="`cat /tmp/ans`"
               if [ "$EFILL" = "1" ]; then
                  apt-get install dc3dd
                  echo "Filling $EDRIVE with ZEROS - please wait........"
                  echo "$(dc3dd wipe=$EDRIVE)" 2>&1
               elif [ "$EFILL" = "2" ]; then
                  apt-get install dcfldd
                  echo "Filling $EDRIVE with RANDOM DATA - please wait........\n"
                  fdisk -l $EDRIVE | head -2
                  msg=$(dcfldd if=/dev/urandom of=$EDRIVE) || echo "$msg" 2>&1
               fi
               echo "Creating Encrypted LUKS container on $EDRIVE....."
               cryptsetup --verify-passphrase --verbose --hash=sha256 --cipher=aes-cbc-essiv:sha256 --key-size=256 luksFormat $EDRIVE
               if [ "$EDRIVE" = "$NEWROOT" ]; then
                  MAPPER=$MAPPERROOT
                  ROOTFORMAT="DONE"
                  ENCRYPTFS=$ROOTFS
               else
                  MAPPER=$MAPPERHOME
                  ENCRYPTFS=$HOMEFS
               fi
               if cryptsetup status $MAPPER|grep "inactive" 1> /dev/null; then
                  echo "Opening LUKS Encrypted container on $EDRIVE with Mapping '$MAPPER'"
                  cryptsetup luksOpen $EDRIVE $MAPPER
               fi
               if mount|grep "/dev/mapper/$MAPPER" 1> /dev/null; then
                  echo "unmounting $/dev/mapper/$MAPPER"
                  umount /dev/mapper/$MAPPER
               fi
               echo "Formatting Encrypted Partition $EDRIVE"
               mkfs.$ENCRYPTFS -q /dev/mapper/$MAPPER
            fi
      else
         #open root & home LUKS mappers
         if cryptsetup status $MAPPERROOT|grep "inactive" 1> /dev/null; then
            echo "Opening LUKS Encrypted container on $NEWROOT with Mapper '$MAPPERROOT'"
            cryptsetup luksOpen $NEWROOT $MAPPERROOT
         elif cryptsetup status $MAPPERHOME|grep "inactive" 1> /dev/null; then
            echo "Opening LUKS Encrypted container on $NEWHOME with Mapper '$MAPPERHOME'"
            cryptsetup luksOpen $NEWHOME $MAPPERHOME
         fi
      fi
   done
   #mount encrypted root & home
   if [ "$ROOTFORMAT" != "DONE" ]; then
      if mount|grep "/dev/mapper/$MAPPERROOT" 1> /dev/null ; then
         echo "unmounting /dev/mapper$MAPPERROOT"; umount /dev/mapper/$MAPPERROOT
      fi
      echo "formatting DESTINATION partition /"
      mkfs.$ROOTFS -q /dev/mapper/$MAPPERROOT
   fi
   echo "mounting /dev/mapper/$MAPPERROOT on /mnt/newroot"
   mountpoint -q /mnt/newroot || mount /dev/mapper/$MAPPERROOT /mnt/newroot
   echo "mounting /dev/mapper/$MAPPERHOME on /mnt/newhome"
   mountpoint -q /mnt/newhome || mount /dev/mapper/$MAPPERHOME /mnt/newhome   
   rm -f /tmp/ans /tmp/ans2
fi   
   
#create new mount points on NEWROOT
MOUNTPOINTS="home proc mnt opt selinux sys boot usr var"
for DIR in $MOUNTPOINTS
do
   if [ ! -d "/mnt/newroot/$DIR" ]; then
      echo "Creating mount point /mnt/newroot/"$DIR
      mkdir /mnt/newroot/$DIR
   fi
done

# copy / format BOOT
if [ "$OLDBOOT" != "$NEWBOOT" ]; then
   if [ "$OLDBOOT" = "$OLDROOT" ]; then
   {   #BOOT is within root at SRC & DEST
      if [ "$NEWBOOT" = "$NEWROOT" ]; then
      {
         if [ -d "/mnt/newboot" ]; then
            rmdir /mnt/newboot
         fi   
         echo "copying $(du -hs --apparent-size /mnt/oldroot/boot) to /mnt/newroot/boot"
         #cp -a /mnt/oldroot/boot/* /mnt/newroot/boot
         tar cf - /mnt/oldroot/boot 2> /dev/null | pv | (cd /mnt/newroot/boot;tar x -f - --strip-components=3)
      }
      else
      # BOOT is separate at DEST
         if mount|grep "$NEWBOOT" 1> /dev/null; then
            echo "unmounting $NEWBOOT"; umount $NEWBOOT
         fi
         echo "formatting DESTINATION partition /BOOT"
         mkfs.$BOOTFS -q $NEWBOOT
         echo "mounting $NEWBOOT on /mnt/newboot"
         mountpoint -q /mnt/newboot || mount $NEWBOOT /mnt/newboot
         echo "mounting $NEWBOOT on /mnt/newroot/boot for CHROOT"
         mount $NEWBOOT /mnt/newroot/boot
         echo "copying $(du -hs --apparent-size /mnt/oldroot/boot) to /mnt/newboot"
         #cp -a /mnt/oldroot/boot/* /mnt/newboot
         tar cf - /mnt/oldroot/boot 2> /dev/null | pv | (cd /mnt/newboot;tar x -f - --strip-components=3)
      fi
      }
   else
      #BOOT is within DEST only
      if [ "$NEWBOOT" = "$NEWROOT" ]; then
      {
         if [ -d "/mnt/newboot" ]; then
            rmdir /mnt/newboot
         fi   
         echo "copying $(du -hs --apparent-size /mnt/oldboot) to /mnt/newroot/boot"
         #cp -a /mnt/oldboot/* /mnt/newroot/boot
         tar cf - /mnt/oldboot 2> /dev/null | pv | (cd /mnt/newroot/boot;tar x -f - --strip-components=2)
      }
      else
      # BOOT is separate at SRC & DEST
      if mount|grep "$NEWBOOT" 1> /dev/null; then
         echo "unmounting $NEWBOOT"; umount $NEWBOOT
      fi
      echo "formatting DESTINATION partition /BOOT"
      mkfs.ext2 -q $NEWBOOT
      echo "mounting "$NEWBOOT" on /mnt/newboot"
      mountpoint -q /mnt/newboot || mount $NEWBOOT /mnt/newboot
      echo "mounting $NEWBOOT on /mnt/newroot/boot for CHROOT"
      mount $NEWBOOT /mnt/newroot/boot
      echo "copying $(du -hs --apparent-size /mnt/oldboot) to /mnt/newboot"
      #cp -a /mnt/oldboot/* /mnt/newboot
      tar cf - /mnt/oldboot 2> /dev/null | pv | (cd /mnt/newboot;tar x -f - --strip-components=2)
      fi
   fi
else
   echo "BOOT not moving - nothing to copy."
   if [ "$NEWBOOT" != "$NEWROOT" ]; then
      echo "mounting "$NEWBOOT" on /mnt/newboot"
      mountpoint -q /mnt/newboot || mount $NEWBOOT /mnt/newboot
      echo "mounting $NEWBOOT on /mnt/newroot/boot for CHROOT"
      mount $NEWBOOT /mnt/newroot/boot
   fi
fi



#copy existing ROOT to new DESTINATION
if [ "$OLDROOT" != "$NEWROOT" ]; then
   COPYDIRS="bin dev etc lib media root sbin tmp"
   for DIR in $COPYDIRS
   do
      echo "copying $(du -hs --apparent-size /mnt/oldroot/$DIR) to /mnt/newroot/$DIR"
      #cp -a /mnt/oldroot/$DIR /mnt/newroot/$DIR
      tar cf - /mnt/oldroot/$DIR 2> /dev/null | pv | (cd /mnt/newroot;tar x -f - --strip-components=2)
   done
else
   echo "ROOT not moving - nothing to copy."
fi

# copy / format VAR
if [ "$OLDVAR" != "$NEWVAR" ]; then
   if [ "$OLDVAR" = "$OLDROOT" ]; then
   {   #var is within root at SRC & DEST
      if [ "$NEWVAR" = "$NEWROOT" ]; then
      {
         if [ -d "/mnt/newvar" ]; then
            rmdir /mnt/newvar
         fi   
         echo "copying $(du -hs --apparent-size /mnt/oldroot/var) to /mnt/newroot/var"
         #cp -a /mnt/oldroot/var/* /mnt/newroot/var
         tar cf - /mnt/oldroot/var 2> /dev/null | pv | (cd /mnt/newroot;tar x -f - --strip-components=2)
      }
      else
      # var is separate at DEST only
         if mount|grep "$NEWVAR" 1> /dev/null; then
            echo "unmounting $NEWVAR"; umount $NEWVAR
         fi
         echo "formatting DESTINATION partition /VAR"
         mkfs.$VARFS -q $NEWVAR
         echo "mounting $NEWVAR on /mnt/newvar"
         mountpoint -q /mnt/newvar || mount $NEWVAR /mnt/newvar
         echo "mounting $NEWVAR on /mnt/newroot/var for CHROOT"
         mount $NEWVAR /mnt/newroot/var
         echo "copying $(du -hs --apparent-size /mnt/oldroot/var) to /mnt/newvar"
         #cp -a /mnt/oldroot/var/* /mnt/newvar
         tar cf - /mnt/oldroot/var 2> /dev/null | pv | (cd /mnt/newvar;tar x -f - --strip-components=3)
      fi
      }
   else
      #var is separate at SRC & within ROOT at DEST
      if [ "$NEWVAR" = "$NEWROOT" ]; then
      {
         if [ -d "/mnt/newvar" ]; then
            rmdir /mnt/newvar
         fi   
         echo "copying $(du -hs --apparent-size /mnt/oldvar) to /mnt/newroot/var"
         #cp -a /mnt/oldvar/* /mnt/newroot/var
         tar cf - /mnt/oldvar 2> /dev/null | pv | (cd /mnt/newroot/var;tar x -f - --strip-components=2)
      }   
      else
      # var is separate at SRC & DEST
      if mount|grep "$NEWVAR" 1> /dev/null; then
         echo "unmounting $NEWVAR"; umount $NEWVAR
      fi
      echo "formatting DESTINATION partition /VAR"
      mkfs.$VARFS -q $NEWVAR
      echo "mounting $NEWVAR on /mnt/newvar"
      mountpoint -q /mnt/newvar || mount $NEWVAR /mnt/newvar
      echo "mounting $NEWVAR on /mnt/newroot/var for CHROOT"
      mount $NEWVAR /mnt/newroot/var
      echo "copying $(du -hs --apparent-size /mnt/oldvar) to /mnt/newvar"
      #cp -a /mnt/oldvar/* /mnt/newvar
      tar cf - /mnt/oldvar 2> /dev/null | pv | (cd /mnt/newvar;tar x -f - --strip-components=2)
      fi
   fi
else
   echo "VAR not moving - nothing to copy."
   if [ "$NEWVAR" != "$NEWROOT" ]; then
      echo "mounting "$NEWVAR" on /mnt/newvar"
      mountpoint -q /mnt/newvar || mount $NEWVAR /mnt/newvar
      echo "mounting $NEWVAR on /mnt/newroot/var for CHROOT"
      mount $NEWVAR /mnt/newroot/var
   fi
fi

# copy HOME to new DESTINATION
if [ "$OLDHOME" = "$OLDROOT" ]; then
   if [ "$NEWHOME" != "$NEWROOT" ]; then
      echo "copying $(du -hs --apparent-size /mnt/oldroot/home) to /mnt/newhome"
      #cp -a /mnt/oldroot/home/* /mnt/newhome
      tar cf - /mnt/oldroot/home 2> /dev/null | pv | (cd /mnt/newhome;tar x -f - --strip-components=3)
   elif [ "$OLDHOME" != "$NEWHOME" ]; then
      echo "copying $(du -hs --apparent-size /mnt/oldroot/home) to /mnt/newroot/home"
      tar cf - /mnt/oldroot/home 2> /dev/null | pv | (cd /mnt/newroot/home;tar x -f - --strip-components=3)
   else
      echo "HOME not moving - nothing to copy"
   fi
elif [ "$OLDHOME" != "$NEWHOME" ]; then
   if [ "$NEWHOME" != "$NEWROOT" ]; then
      echo "copying $(du -hs --apparent-size /mnt/oldhome) to /mnt/newhome"
      #cp -a /mnt/oldhome/* /mnt/newhome
      tar cf - /mnt/oldhome 2> /dev/null | pv | (cd /mnt/newhome;tar x -f - --strip-components=2)
   else
      echo "copying $(du -hs --apparent-size /mnt/oldhome) to /mnt/newroot/home"
      tar cf - /mnt/oldhome 2> /dev/null | pv | (cd /mnt/newroot/home;tar x -f - --strip-components=2)
   fi
fi

#copy AntiX menu script
if [ "$OLDROOT" != "$NEWROOT" ]; then
   if [ -d "/mnt/oldroot/antiX-install" ]; then
      echo "copying $(du -hs --apparent-size /mnt/oldroot/antiX-install) to /mnt/newroot/antiX-install"
      #cp -a /mnt/oldroot/antiX-install /mnt/newroot
      tar cf - /mnt/oldroot/antiX-install 2> /dev/null | pv | (cd /mnt/newroot;tar x -f - --strip-components=2)
      rm -r /mnt/oldroot/antiX-install
   fi
fi

# copy / format USR (must be done last)
if [ "$OLDUSR" = "$NEWUSR" -a "$OLDROOT" != "$NEWROOT" ]; then
   #install NEW Antix / Mepis into the partition which will become /USR to speed things up
   echo "Deleting directories from old install & moving /USR up one level"
   REMOVEDIRS="bin boot dev etc home lib lost+found media mnt opt proc root sbin selinux sys tmp var"
   for DIR in $REMOVEDIRS
   do
   echo "removing /"$DIR
   rm -r /mnt/oldroot/$DIR
   done
   echo "moving /usr up one level"
   mv /mnt/oldroot/usr/* -t /mnt/oldroot
   echo "removing original /usr"
   rm -r /mnt/oldroot/usr
   echo "mounting $OLDROOT to /mnt/newroot/usr for CHROOT"   
   mount $OLDROOT /mnt/newroot/usr
elif [ "$OLDUSR" = "$OLDROOT" ]; then
   #USR is within root at SRC & DEST
   if [ "$NEWUSR" = "$NEWROOT" -a "$NEWUSR" != "$OLDUSR" ]; then
      if [ -d "/mnt/newusr" ]; then
         rmdir /mnt/newusr
      fi   
      echo "copying $(du -hs --apparent-size /mnt/oldroot/usr) to /mnt/newroot/usr"
      #cp -a /mnt/oldroot/usr/* /mnt/newroot/usr
      tar cf - /mnt/oldroot/usr 2> /dev/null | pv | (cd /mnt/newroot;tar x -f - --strip-components=2)
   elif [ "$NEWUSR" != "$OLDUSR" ]; then
      # USR is separate at DEST
      if mount|grep "$NEWUSR" 1> /dev/null; then
         echo "unmounting $NEWUSR"; umount $NEWUSR
      fi
      echo "formatting DESTINATION partition /USR"
      mkfs.$USRFS -q $NEWUSR
      echo "mounting $NEWUSR on /mnt/newusr"
      mountpoint -q /mnt/newusr || mount $NEWUSR /mnt/newusr
      echo "mounting $NEWUSR on /mnt/newroot/usr for CHROOT"
      mount $NEWUSR /mnt/newroot/usr
      echo "copying $(du -hs --apparent-size /mnt/oldroot/usr) to /mnt/newusr"
      #cp -a /mnt/oldroot/usr/* /mnt/newusr
      tar cf - /mnt/oldroot/usr 2> /dev/null | pv | (cd /mnt/newusr;tar x -f - --strip-components=3)
   fi
elif [ "$OLDUSR" != "$NEWUSR" ]; then
   #USR is within root at DEST only
   if [ "$NEWUSR" = "$NEWROOT" ]; then
      if [ -d "/mnt/newusr" ]; then
         rmdir /mnt/newusr
      fi   
   echo "copying $(du -hs --apparent-size /mnt/oldusr) to /mnt/newroot/usr"
   #cp -a /mnt/oldusr/* /mnt/newroot/usr
   tar cf - /mnt/oldusr 2> /dev/null | pv | (cd /mnt/newroot/usr;tar x -f - --strip-components=2)
   else   
      # USR is separate at SRC & DEST
      if mount|grep "$NEWUSR" 1> /dev/null; then
         echo "unmounting $NEWUSR"; umount $NEWUSR
      fi
      echo "formatting DESTINATION partition /USR"
      mkfs.$USRFS -q $NEWUSR
      echo "mounting $NEWUSR on /mnt/newusr"
      mountpoint -q /mnt/newusr || mount $NEWUSR /mnt/newusr
      echo "mounting $NEWUSR on /mnt/newroot/usr for CHROOT"
      mount $NEWUSR /mnt/newroot/usr
      echo "copying $(du -hs --apparent-size /mnt/oldusr) to /mnt/newusr"
      #cp -a /mnt/oldusr/* /mnt/newusr
      tar cf - /mnt/oldusr 2> /dev/null | pv | (cd /mnt/newusr;tar x -f - --strip-components=2)
   fi
else
   echo "USR not moving - nothing to copy."
   if [ "$NEWUSR" != "$NEWROOT" ]; then
      echo "mounting "$NEWUSR" on /mnt/newusr"
      mountpoint -q /mnt/newusr || mount $NEWUSR /mnt/newusr
      echo "mounting $NEWUSR on /mnt/newroot/usr for CHROOT"
      mount $NEWUSR /mnt/newroot/usr
   fi
fi

#update fstab & clear crypttab
echo $DISK >> /tmp/sedisk; SEDISK=$(sed 's,\/,\\/,g' /tmp/sedisk)
echo "/dev/mapper" >> /tmp/sedmap; SEDMAP=$(sed 's,\/,\\/,g' /tmp/sedmap)
echo "making backups /etc/fstab.bak & /etc/crypttab.bak"
sed -i.bak /$SEDISK/d /mnt/newroot/etc/fstab
sed -i.bak /$SEDISK/d /mnt/newroot/etc/crypttab
sed -i /$SEDMAP/d /mnt/newroot/etc/fstab
rm /tmp/sedisk /tmp/sedmap
echo "fstab & crypttab /dev lines removed"
if [ "$R" = "1" ]; then
   echo "$NEWROOT / $ROOTFS errors=remount-ro 0 1" >> /mnt/newroot/etc/fstab
   if [ "$NEWHOME" != "$NEWROOT" ]; then
      echo "$NEWHOME /home $HOMEFS defaults 0 2" >> /mnt/newroot/etc/fstab
   fi
else
   echo "/dev/mapper/$MAPPERROOT / $ROOTFS errors=remount-ro 0 1" >> /mnt/newroot/etc/fstab
   if [ "$NEWHOME" != "$NEWROOT" ]; then
   echo "/dev/mapper/$MAPPERHOME /home $HOMEFS defaults 0 2" >> /mnt/newroot/etc/fstab
   fi
fi
if [ "$NEWBOOT" != "$NEWROOT" ]; then
   echo "$NEWBOOT /boot $BOOTFS defaults 0 2" >> /mnt/newroot/etc/fstab
fi
if [ "$NEWUSR" != "$NEWROOT" ]; then
   echo "$NEWUSR /usr $USRFS defaults 0 2" >> /mnt/newroot/etc/fstab
fi
if [ "$NEWVAR" != "$NEWROOT" ]; then
   echo "$NEWVAR /var $VARFS defaults 0 2" >> /mnt/newroot/etc/fstab
fi
echo "/mnt/newroot/etc/fstab updated"
ENDMSG="/etc/fstab"

#update menu.lst
echo "starting menu.lst update"
if [ "$NEWBOOT" != "$NEWROOT" ]; then
   if [ ! -f "/mnt/newboot/grub/grub.cfg" ]; then
      SEDMENU=\/mnt\/newboot\/grub\/menu.lst
   fi
else
   if [ ! -f "/mnt/newroot/boot/grub/grub.cfg" ]; then
      SEDMENU=\/mnt\/newroot\/boot\/grub\/menu.lst
   fi
fi
#only run for Legacy GRUB
if [ "$SEDMENU" ]; then
   if [ "$NEWBOOT" != "$NEWROOT" ]; then      
      if [ "$OLDBOOT" = "$OLDROOT" ]; then
         echo "updating: gfxmenu /grub/message"
         sed -i.bak ''$(sed -n '/\/grub\/message/=' $SEDMENU)' c\gfxmenu \/grub\/message' $SEDMENU
         LINE=$(sed -n '/kernel \/boot/=' $SEDMENU)
         KERNEL=$(sed -n ''$LINE'p' $SEDMENU)
         echo "updating: kernel ${KERNEL#kernel /boot}"
         sed -i "$LINE c\kernel ${KERNEL#kernel /boot}" $SEDMENU
         LINE=$(sed -n '/initrd \/boot/=' $SEDMENU)
         INITRD=$(sed -n ''$LINE'p' $SEDMENU)
         echo "updating: initrd ${INITRD#initrd /boot}"
         sed -i "$LINE c\initrd ${INITRD#initrd /boot}" $SEDMENU
      fi
   else
      if [ "$OLDBOOT" != "$OLDROOT" ]; then
         echo "updating: gfxmenu /boot/grub/message"
         sed -i.bak ''$(sed -n '/\/grub\/message/=' $SEDMENU)' c\gfxmenu \/boot\/grub\/message' $SEDMENU
         LINE=$(sed -n '/kernel \/vmlinuz/=' $SEDMENU)
         KERNEL=$(sed -n ''$LINE'p' $SEDMENU)
         echo "updating: kernel /boot/vmlinuz${KERNEL#kernel /vmlinuz}"
         sed -i "$LINE c\kernel /boot/vmlinuz${KERNEL#kernel /vmlinuz}" $SEDMENU
         LINE=$(sed -n '/initrd \/initrd/=' $SEDMENU)
         INITRD=$(sed -n ''$LINE'p' $SEDMENU)
         echo "updating: initrd /boot/initrd${INITRD#initrd /initrd}"
         sed -i "$LINE c\initrd /boot/initrd${INITRD#initrd /initrd}" $SEDMENU
      fi
   fi
   GRUBPART=$(echo $NEWBOOT | tr -cd [:digit:]);GRUBPART=$((GRUBPART -1))
   GRUBDISK=$(echo ${DISK#???????} | tr '[a-j]' '[0-9]')
   LINE="$(sed -n '/root (hd/=' $SEDMENU)"
   echo "updating: root (hd$GRUBDISK,$GRUBPART)"
   sed -i "$LINE c\root (hd$GRUBDISK,$GRUBPART)" $SEDMENU   
   echo $OLDROOT >> /tmp/sedoldroot; echo $NEWROOT >> /tmp/sednewroot
   SEDOLDROOT=$(sed 's,\/,\\/,g' /tmp/sedoldroot);SEDNEWROOT=$(sed 's,\/,\\/,g' /tmp/sednewroot)
   if blkid $OLDROOT|grep "crypto_LUKS" 1> /dev/null; then
      if [ "$R" = "1" ]; then
         echo "updating: root=$NEWROOT"
         sed -i 's/root=\/dev\/mapper\/'$MAPPERROOT'/root='$SEDNEWROOT'/g' $SEDMENU
      fi
   elif [ "$R" = "2" ]; then
      echo "updating: root=/dev/mapper/$MAPPERROOT"
      sed -i 's/root='$SEDOLDROOT'/root=\/dev\/mapper\/'$MAPPERROOT'/g' $SEDMENU
   elif [ "$R" = "1" ]; then
      echo "updating: root=$NEWROOT"
      sed -i 's/root='$SEDOLDROOT'/root='$SEDNEWROOT'/g' $SEDMENU   
   fi
   LINE="$(sed -n '/title antiX/=' $SEDMENU)"; LINUX="$(cat $VERSION | awk '{print $1}')"
   echo "updating: title $LINUX at ${NEWROOT#/dev/}, kernel $(uname -r)"
   sed -i "$LINE c\title $LINUX at ${NEWROOT#/dev/}, kernel $(uname -r)" $SEDMENU
   rm /tmp/sedoldroot /tmp/sednewroot
   ENDMSG="$ENDMSG \n/boot/grub/menu.lst"
else
   echo "GRUB2 detected skipping menu.lst update"
   ENDMSG="$ENDMSG \n/boot/grub/grub.cfg"
fi

## CHROOT into new install
echo "binding /dev /dev/pts /proc /sys for CHROOT"
mount --bind /dev /mnt/newroot/dev
mount -t devpts none /mnt/newroot/dev/pts
mount --bind /proc /mnt/newroot/proc
mount --bind /sys /mnt/newroot/sys

#normal install
if [ "$R" = "1" ]; then
   echo "chrooting into your new install & updating initramfs..."
   chroot /mnt/newroot /bin/sh -c "update-initramfs -u -t -k all"

#install to encrypted partitions
elif [ "$R" = "2" ]; then
   # Add Modules needed to mount LUKS on booting
   echo "adding crypt modules......."
   echo "dm_mod" >> /mnt/newroot/etc/initramfs-tools/modules
   echo "dm_crypt" >> /mnt/newroot/etc/initramfs-tools/modules
   echo "aes_generic" >> /mnt/newroot/etc/initramfs-tools/modules
   echo "aes-i586" >> /mnt/newroot/etc/initramfs-tools/modules
   echo "sha256_generic" >> /mnt/newroot/etc/initramfs-tools/modules
   if [ `getconf LONG_BIT` = "64" ]; then
      echo "aes-x86_64 " >> /mnt/newroot/etc/initramfs-tools/modules
   fi   
   #if [ ! -f "/mnt/newroot/etc/keys/$MAPPERHOME" ]; then
      read -p "Create LUKS Keyfile for HOME in /etc/keys ? (y/n): " ANSWER
      case $ANSWER in
         y | yes)
         echo "creating key for $NEWHOME...."
         if [ ! -d "/mnt/newroot/etc/keys" ]; then
            mkdir /mnt/newroot/etc/keys
         fi
         dd if=/dev/random of=/mnt/newroot/etc/keys/$MAPPERHOME bs=32 count=1
         chmod 400 /mnt/newroot/etc/keys/$MAPPERHOME
         cryptsetup luksAddKey $NEWHOME /mnt/newroot/etc/keys/$MAPPERHOME
         echo "updating /etc/crypttab....."
         echo "$MAPPERROOT      $NEWROOT      none      luks" >> /mnt/newroot/etc/crypttab
         echo "$MAPPERHOME      $NEWHOME      /etc/keys/$MAPPERHOME      luks" >> /mnt/newroot/etc/crypttab
         ;;
         *)
         if [ ! cat /mnt/newroot/etc/crypttab ]; then
            echo "updating /etc/crypttab....."
            echo "$MAPPERROOT      $NEWROOT      none      luks" >> /mnt/newroot/etc/crypttab
            echo "$MAPPERHOME      $NEWHOME      none      luks" >> /mnt/newroot/etc/crypttab
         fi   
         ;;
      esac
   #else
      #echo "updating /etc/crypttab....."
      #echo "$MAPPERROOT      $NEWROOT      none      luks" >> /mnt/newroot/etc/crypttab
      #echo "$MAPPERHOME      $NEWHOME      /etc/keys/$MAPPERHOME      luks" >> /mnt/newroot/etc/crypttab
   #fi
   echo "chrooting into your new install & installing Cryptsetup..."
   chroot /mnt/newroot /bin/bash -c "apt-get update && apt-get install -y cryptsetup"
   echo "Overriding update-initramfs with -u -t -k all"
   chroot /mnt/newroot /bin/bash -c "update-initramfs -u -t -k all"
   ENDMSG="$ENDMSG \n/etc/crypttab"
fi

echo "chrooting into your new install & running grub-install $DISK"
chroot /mnt/newroot /bin/bash -c "grub-install $DISK"
echo "chrooting into your new install & running update-grub"
chroot /mnt/newroot /bin/bash -c "update-grub"

#tidy root if it hasn't moved anywhere
if [ "$OLDROOT" = "$NEWROOT" ]; then
   echo "root did not move so tidying up"
   for ROOTCLEAN in "$NEWBOOT boot $OLDBOOT" "$NEWUSR usr $OLDUSR" "$NEWVAR var $OLDVAR"
   do
      set -- $ROOTCLEAN
      if [ "$1" != "$OLDROOT" -a "$3" = "$OLDROOT" ]; then
         if mountpoint -q "/mnt/newroot/$2"; then
            echo "unmounting /mnt/newroot/$2"; umount "/mnt/newroot/$2"
            echo "removing /mnt/oldroot/$2"; rm -R "/mnt/oldroot/$2"
            echo "re-creating mount point /mnt/oldroot/$2"; mkdir "/mnt/oldroot/$2"
         fi
      else
         echo "Nothing to tidy for $2"
      fi
   done
fi

dialog --title "System Moving Complete" \
          --msgbox "\nYour system has been moved successfully to: \n
          \nTO: NEWBOOT ($NEWBOOT)
          \nTO: NEWROOT ($NEWROOT)
      \nTO: NEWUSR  ($NEWUSR)
      \nTO: NEWVAR  ($NEWVAR)
      \nTO: NEWHOME ($NEWHOME)         
          \n\nThe following files have been backed up & updated:
          \n\n$ENDMSG
          \n\nYou can now reboot into your system." 20 54
