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

## # Create file-header
## cat << EOF > ${FSTAB}
## #
## # /etc/fstab
## # Created by anaconda on Mon Feb 22 17:08:22 2016
## #
## # Accessible filesystems, by reference, are maintained under '/dev/disk'
## # See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
## #
## EOF

PARTINFO=($(lsblk -nlf ${CHROOTDEV} | \
            awk '{printf("%s:%s:%s:%s\n",$1,$2,$3,$5)}' | sed '/:$/d'))

CNT=0
PARTLEN=${#PARTINFO[@]}
while [[ ${CNT} -lt ${PARTLEN} ]]
do
   PARTNAME=$(echo "${PARTINFO[${CNT}]}" | cut -d ":" -f 1)
   PARTTYPE=$(echo "${PARTINFO[${CNT}]}" | cut -d ":" -f 2)
   PARTLABL=$(echo "${PARTINFO[${CNT}]}" | cut -d ":" -f 3)
   PARTMONT=$(echo "${PARTINFO[${CNT}]}" | cut -d ":" -f 4)
   echo "${PARTINFO[${CNT}]}"
   echo ${PARTNAME} ${PARTTYPE} ${PARTLABL} ${PARTMONT}
   CNT=$((${CNT} + 1))
done
