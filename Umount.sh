#!/bin/sh
#
# Script to clean up all devices mounted under $CHROOT
#
#################################################################

for BLK in $(mount | grep "${CHROOT}" | awk '{ print $3 }' | sort -r)
do
   umount "${BLK}"
done
