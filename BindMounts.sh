#!/bin/sh
#
# Take care of bind-mounts
#
#################################################################
BINDSOURCES=$(grep -v $CHROOT /proc/mounts | sed '{
                 /rootfs/d
                 /dev\/xvd/d
                 /\/user\//d
              }' | awk '{print $2}')

for MOUNT in ${BINDSOURCES}
do
   if [[ ! -d ${CHROOT}${MOUNT} ]]
   then
      mkdir -p ${CHROOT}${MOUNT} && \
         echo "Creating ${CHROOT}${MOUNT}" || break
   fi
   mount -o bind ${MOUNT} ${CHROOT}${MOUNT}
done
