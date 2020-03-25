#!/bin/bash
#
# Script to clean up all devices mounted under $CHROOT
#
#################################################################
CHROOT="${CHROOT:-/mnt/ec2-root}"

while read -r BLK
do
   if [[ ${DEBUG:-} == true ]]
   then
      echo "umount: $BLK"
   fi
   umount "$BLK"
done < <( cut -d " " -f 3 <( mount )  | grep "${CHROOT}" | sort -r )
