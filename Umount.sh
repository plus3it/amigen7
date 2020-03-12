#!/bin/sh
#
# Script to clean up all devices mounted under $CHROOT
#
#################################################################
CHROOT="${CHROOT:-/mnt/ec2-root}"

for BLK in $(mount | awk '{ print $3 }' | grep "^${CHROOT}" | sort -r)
do
   echo "umount: $BLK"
   umount "$BLK"
done
