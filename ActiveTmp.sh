#!/bin/sh
# shellcheck disable=SC2181
#
# Script to ensure that host has /tmp as tmpfs
#
#################################################################
SVCNAM="tmp.mount"
TMPSVC=$(systemctl is-enabled ${SVCNAM})

case ${TMPSVC} in
   masked)
      systemctl unmask ${SVCNAM} && \
        systemctl enable ${SVCNAM} && \
        systemctl start ${SVCNAM} 
      if [ $? -eq 0 ]
      then
         echo "/tmp mounted as tmpfs"
         exit 0
      else
         echo "Failed to mount /tmp as tmpfs." > /dev/stderr
         exit 1
      fi
      ;;
   disabled)
        systemctl enable ${SVCNAM} && \
        systemctl start ${SVCNAM} 
      if [ $? -eq 0 ]
      then
         echo "/tmp mounted as tmpfs"
         exit 0
      else
         echo "Failed to mount /tmp as tmpfs." > /dev/stderr
         exit 1
      fi
      ;;
   enabled)
      systemctl restart ${SVCNAM} 
      if [ $? -eq 0 ]
      then
         echo "/tmp mounted as tmpfs"
         exit 0
      else
         echo "Failed to mount /tmp as tmpfs." > /dev/stderr
         exit 1
      fi
      ;;
esac
