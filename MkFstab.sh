#!/bin/sh
#
# Script to set up the chroot'ed /etc/fstab
#
#################################################################
CHROOT="${CHROOT:-/mnt/ec2-root}"
CHROOTDEV=${1:-UNDEF}
FSTAB="${CHROOT}/etc/fstab"

# Check for arguments
if [[ $# -lt 1 ]]
then
   echo "Missing parameter(s). Aborting..." > /dev/stderr
   exit 1
fi

if [[ -b $(readlink -f "${CHROOTDEV}") ]]
then
  PART1="$(e2label ${CHROOTDEV}2)"
  if [[ $(file -sL "${CHROOTDEV}"2 | grep -q LVM)$? -eq 0 ]]
  then
     VGNAME=$(pvdisplay -c ${CHROOTDEV}2 | awk -F ":" '{print $2}')
     echo $VGNAME
  elif [[ $(file -sL "${CHROOTDEV}"2 | grep -q "SGI XFS")$? -eq 0 ]]
     PART2="$(xfs_admin -l ${CHROOTDEV}2 | sed -e 's/"$//' -e 's/^.*"//')"
  elif [[ $(file -sL "${CHROOTDEV}"2 | grep -q ext[2-4])$? -eq 0 ]]
     PART2="$(e2label ${CHROOTDEV}2)"
  fi
fi   


exit
# Create file-header
cat << EOF > ${FSTAB}
#
# /etc/fstab
# Created by anaconda on Mon Feb 22 17:08:22 2016
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
EOF

