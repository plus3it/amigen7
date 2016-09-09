#!/bin/sh
#
# Script to set up the chroot'ed /etc/fstab
# - Pass in the name of the EBS device the chroot was built on
#   top of.
#
#################################################################
CHROOT="${CHROOT:-/mnt/ec2-root}"
CHROOTDEV=${1:-UNDEF}
FSTAB="${CHROOT}/etc/fstab"
CHGRUBDEF="${CHROOT}/etc/default/grub"
ROOTLN=""

# Check for arguments
if [[ $# -lt 1 ]]
then
   echo "Missing parameter(s). Aborting..." > /dev/stderr
   exit 1
fi

# Make sure argument is valid
if [[ ! -e /sys/block/$(basename ${CHROOTDEV}) ]]
then
   echo "Invalid block device provided. Aborting..." > /dev/stderr
   exit 1
fi

# Shouldn't need this, but the RPM seems to be broken (20160315)
if [[ ! -f ${CHGRUBDEF} ]]
then
   printf "The grub2-tools RPM (vers. "
   printf "$(rpm -q grub2-tools --qf '%{version}-%{release}\n')) "
   printf "was faulty. Manufacturing a ${CHGRUBDEF}.\n"

   (
    printf "GRUB_TIMEOUT=5\n"
    printf "GRUB_DISTRIBUTOR=\"$(sed 's, release .*$,,g' /etc/system-release)\"\n"
    printf "GRUB_DEFAULT=saved\n"
    printf "GRUB_DISABLE_SUBMENU=true\n"
    printf "GRUB_DISABLE_LINUX_UUID=true\n"
    printf "GRUB_DISABLE_RECOVERY=\"true\"\n"
    printf "GRUB_TERMINAL_OUTPUT=\"console\"\n"
    printf "GRUB_CMDLINE_LINUX=\"vconsole.keymap=us crashkernel=auto "
    printf "vconsole.font=latarcyrheb-sun16 rhgb quiet console=ttyS0 "
    printf "fips=1 boot=LABEL=/boot\"\n"
   ) > ${CHGRUBDEF}

   if [[ $? -ne 0 ]]
   then
      echo "Failed..." >> /dev/stderr
      exit 1
   fi
fi

# Create and install a GRUB2 config file (etc.)
chroot ${CHROOT} /bin/bash -c "/sbin/grub2-install ${CHROOTDEV}"
chroot ${CHROOT} /bin/bash -c "/sbin/grub2-mkconfig  > /boot/grub2/grub.cfg"
CHROOTKRN=$(chroot $CHROOT rpm --qf '%{version}-%{release}.%{arch}\n' -q kernel)
chroot ${CHROOT} dracut -fv /boot/initramfs-${CHROOTKRN}.img ${CHROOTKRN}
