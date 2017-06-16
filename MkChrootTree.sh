#!/bin/bash
# shellcheck disable=SC2015
#
# Setup/mount chroot'ed volumes/partitions
# * Takes the dev-path hosting the /boot and LVM partitions as argument
#
#######################################################################
CHROOTDEV=${1:-UNDEF}
BOOTDEV=${CHROOTDEV}1
LVMDEV=${CHROOTDEV}2
ALTROOT="${CHROOT:-/mnt/ec2-root}"

# Generic logging outputter - extend to increase output destinations
function err_out() {
   echo "${2}"
   exit "${1}"
}

# Can't do anything if we don't have an EBS to operate on
if [[ ${CHROOTDEV} = UNDEF ]]
then
   err_out 1 "Must supply name of device to use (e.g., /dev/xvdg)"
fi

if [ -d "${ALTROOT}" ]
then
   echo "Found ${ALTROOT}: proceeding..."
elif [ -e "${ALTROOT}" ] && [ ! -d "${ALTROOT}" ]
then
   err_out 1 "Found ${ALTROOT} but it's not usable as mount-point"
else
   printf "Requested chroot [%s] not found. Attempting to create... " "${ALTROOT}"
   install -d -m 0755 "${ALTROOT}" || err_out 1 "Failed to create ${ALTROOT}."
   echo "Success!"
fi

VGNAME=$(lsblk -i -o NAME,TYPE "${LVMDEV}" | grep -w lvm | \
         sed 's/^ *.-//' | cut -d "-" -f 1 | uniq)

# Mount filesystems
if [[ ${#VGNAME} -gt 0 ]]
then

   # Ensure all LVM volumes are active
   vgchange -a y "${VGNAME}" || err_out 2 "Failed to activate LVM"

   # Mount chroot base device
   echo "Mounting /dev/${VGNAME}/rootVol to ${ALTROOT}"
   mount "/dev/${VGNAME}/rootVol" "${ALTROOT}/" || err_out 2 "Mount Failed"

   # Prep for next-level mounts
   mkdir -p "${ALTROOT}"/{var,opt,home,boot,etc} || err_out 3 "Mountpoint Create Failed"

   # Mount the boot-root
   echo "Mounting ${BOOTDEV} to ${ALTROOT}/boot"
   mount "${BOOTDEV}" "${ALTROOT}/boot/" || err_out 2 "Mount Failed"

   # Mount first of /var hierarchy
   echo "Mounting /dev/${VGNAME}/varVol to ${ALTROOT}/var"
   mount "/dev/${VGNAME}/varVol" "${ALTROOT}/var/" || err_out 2 "Mount Failed"

   # Prep next-level mountpoints
   mkdir -p "${ALTROOT}"/var/{cache,log,lock,lib/{,rpm},tmp}

   # Mount log volume
   echo "Mounting /dev/${VGNAME}/logVol to ${ALTROOT}/var/log"
   mount "/dev/${VGNAME}/logVol" "${ALTROOT}/var/log" 

   # Mount audit volume
   mkdir "${ALTROOT}/var/log/audit"
   echo "Mounting /dev/${VGNAME}/auditVol to ${ALTROOT}/var/log/audit"
   mount "/dev/${VGNAME}/auditVol" "${ALTROOT}/var/log/audit"

   # Mount the rest
   echo "Mounting /dev/${VGNAME}/homeVol to ${ALTROOT}/home"
   mount "/dev/${VGNAME}/homeVol" "${ALTROOT}/home/"
else
   ########################################################
   ## NOTE: This section assumes a simple, two-partition ##
   ##       disk with "/boot" on primary-partition 1 and ##
   ##       "/" on primary-partition 2. This script also ##
   ##       assumes that each partition is labeled.      ##
   ########################################################

   MNTPTS=(/boot /)
   IFS=$'\n'; PARTS=( $(lsblk -i "${CHROOTDEV}" | awk '/ part *$/{ print $1}' | \
                        sed 's/^.-//') )

   # Iterate partitions and mount
   for (( IDX=${#PARTS[@]}-1 ; IDX>=0 ; IDX-- ))
   do
      # Get partition-label
      LABEL=$(e2label "/dev/${PARTS[IDX]}")

      # Ensure mount-point exists
      if [[ ! -d ${ALTROOT}${MNTPTS[IDX]} ]]
      then
         mkdir -p "${ALTROOT}${MNTPTS[IDX]}"
      fi

      # Mount partition by label
      mount LABEL="${LABEL}" "${ALTROOT}${MNTPTS[IDX]}"
   done

fi


# Prep for loopback mounts
mkdir -p "${ALTROOT}"/{proc,sys,dev/{pts,shm}}

# Create base dev-nodes
mknod -m 600 "${ALTROOT}"/dev/console c 5 1
mknod -m 666 "${ALTROOT}"/dev/null c 1 3
mknod -m 666 "${ALTROOT}"/dev/zero c 1 5
mknod -m 666 "${ALTROOT}"/dev/random c 1 8
mknod -m 666 "${ALTROOT}"/dev/urandom c 1 9
mknod -m 666 "${ALTROOT}"/dev/tty c 5 0
mknod -m 666 "${ALTROOT}"/dev/ptmx c 5 2
chown root:tty "${ALTROOT}"/dev/ptmx


# Bind-mount everything else
BINDSOURCES=( $(grep -v "${ALTROOT}" /proc/mounts | sed '{
                 /^none/d
                 /\/tmp/d
                 /rootfs/d
                 /dev\/xvd/d
                 /\/user\//d
                 /\/mapper\//d
                 /^cgroup/d
              }' | awk '{print $2}' | sort -u) )

for MOUNT in "${BINDSOURCES[@]}"
do
   if [[ ! -d ${ALTROOT}${MOUNT} ]]
   then
      mkdir -p "${ALTROOT}${MOUNT}" && \
         echo "Creating ${ALTROOT}${MOUNT}" || break
   fi
   echo "Bind-mounting ${MOUNT} to ${ALTROOT}${MOUNT}"
   mount -o bind "${MOUNT}" "${ALTROOT}${MOUNT}"
done
