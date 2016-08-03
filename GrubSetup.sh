#!/bin/sh
#
# Script to set up the chroot'ed /etc/fstab
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

# Shouldn't need this, but the RPM seems to be broken (20160315)
if [[ ! -f ${CHGRUBDEF} ]]
then
   printf "The grub2-tools RPM (vers. "
   printf "$(rpm -q grub2-tools --qf '%{version}-%{release}\n')) "
   printf "was faulty. Manufacturing a ${CHGRUBDEF}.\n"

   ROOTVG=$(lvdisplay ${CHROOTDEV} 2>&1 | awk '/VG Name/{print $3}')
   if [[ "${ROOTVG}" = "" ]]
   then
      PRTLBL=$(e2label /dev/xvda2 2> /dev/null)
      if [[ "${PRTLBL}" = "" ]]
      then
         echo "Can't validate root-dev. Aborting..." > /dev/stderr
         exit 1
      else
         ROOTLN="root=LABEL=${PRTLBL}"
      fi
   else
      echo "Root is LVM-hosted"
      ROOTLN="root=/dev/${CHROOTDEV}"
   fi

   (
    printf "GRUB_TIMEOUT=5\n"
    printf "GRUB_DISTRIBUTOR=\"$(sed 's, release .*$,,g' /etc/system-release)\"\n"
    printf "GRUB_DEFAULT=saved\n"
    printf "GRUB_DISABLE_SUBMENU=true\n"
    printf "GRUB_DISABLE_LINUX_UUID=true\n"
    printf "GRUB_DISABLE_RECOVERY=\"true\"\n"
    printf "GRUB_TERMINAL_OUTPUT=\"console\"\n"
    printf "GRUB_CMDLINE_LINUX=\"ro vconsole.keymap=us crashkernel=auto "
    printf "vconsole.font=latarcyrheb-sun16 rhgb quiet console=ttyS0\"\n"
   ) > ${CHGRUBDEF}

   if [[ $? -ne 0 ]]
   then
      echo "Failed..." >> /dev/stderr
      exit 1
   fi
fi


# Create a GRUB2 config file
chroot ${CHROOT} /sbin/grub2-install ${CHROOTDEV}
chroot ${CHROOT} /sbin/grub2-mkconfig  > ${CHROOT}/boot/grub2/grub.cfg
CHROOTKRN=$(chroot $CHROOT rpm --qf '%{version}-%{release}.%{arch}\n' -q kernel)
chroot ${CHROOT} dracut -fv /boot/initramfs-${CHROOTKRN}.img ${CHROOTKRN}
