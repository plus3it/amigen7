#!/bin/bash
#
# Script to nuke all traces of prior scripts activities from the AMI EBS
#
# DO NOT USE THIS UNTIL YOU HAVE SNAPSHOTTED THE EBS FOR AMI CREATION
#
####################################################################
TARGET=${1:-UNDEF}

function err_out() {
   echo $2
   exit $1
}

if [ ${TARGET} = "UNDEF" ]
then
   err_out 1 "Failed to supply a target for setup. Aborting!"
elif [ ! -b ${TARGET} ]
then
   err_out 2 "Device supplied not valid. Aborting!"
else
   BASEDEV=`basename ${TARGET}`
   stat -t -c "%n" /sys/block/`basename ${TARGET}` > /dev/null 2>&1 || \
      err_out 3 "Need the *base* devnode. Aborting!"
fi

# Nuke the un-needed VG
vgremove -f VolGroup00 || err_out

# Clear the MBR and partition table
dd if=/dev/zero of=${TARGET} bs=512 count=1 || err_out

