#!/bin/bash
# shellcheck disable=SC2015,SC2207
#
# Setup/mount chroot'ed volumes/partitions
# * Takes the dev-path hosting the /boot and LVM partitions as argument
#
#######################################################################
CHROOTDEV=${1:-UNDEF}
ALTROOT="${CHROOT:-/mnt/ec2-root}"
DEVFSTYP="${2:-ext4}"
GEOMETRYSTRING="${3:-/:rootVol:4,swap:swapVol:2,/home:homeVol:1,/var:varVol:2,/var/log:logVol:2,/var/log/audit:auditVol:100%FREE}"

if [[ ${CHROOTDEV} =~ /dev/nvme ]]
then
   PARTPRE="p"
else
   PARTPRE=""
fi

BOOTDEV=${CHROOTDEV}${PARTPRE}1
LVMDEV=${CHROOTDEV}${PARTPRE}2


# Generic logging outputter - extend to increase output destinations
function err_out() {
   echo "${2}"
   exit "${1}"
}

# Set up base mounts using info from SORTEDARRAY
function FlexMount {
   local ELEM
   local MOUNTINFO
   local MOUNTPT
   local PARTITIONARRAY
   local PARTITIONSTR

   declare -A MOUNTINFO
   PARTITIONSTR="${GEOMETRYSTRING}"

   # Convert ${PARTITIONSTR} to iterable partition-info array
   IFS=',' read -r -a PARTITIONARRAY <<< "${PARTITIONSTR}"
   unset IFS

   # Create associative-array with mountpoints as keys
   for ELEM in ${PARTITIONARRAY[*]}
   do
      MOUNTINFO[${ELEM//:*/}]=${ELEM#*:}
   done

   # Ensure all LVM volumes are active
   vgchange -a y "${VGNAME}" || err_out 2 "Failed to activate LVM"

   # Mount volumes
   for MOUNTPT in $( echo "${!MOUNTINFO[*]}" | tr " " "\n" | sort )
   do

      # Ensure mountpoint exists
      if [[ ! -d ${ALTROOT}/${MOUNTPT} ]]
      then
          install -dDm 000755 "${ALTROOT}/${MOUNTPT}"
      fi

      # Mount the filesystem
      if [[ ${MOUNTPT} == /* ]]
      then
         echo "Mounting '${ALTROOT}${MOUNTPT}'..."
         mount -t "${DEVFSTYP}" "/dev/${VGNAME}/${MOUNTINFO[${MOUNTPT}]//:*/}" \
           "${ALTROOT}${MOUNTPT}" || \
             err_out 1 "Unable to mount /dev/${VGNAME}/${MOUNTINFO[${MOUNTPT}]//:*/}"
      else
         echo "Skipping '${MOUNTPT}'..."
      fi
   done

   # Ensure next-level mountpoints in / all exist
   mkdir -p "${ALTROOT}"/{var,opt,home,boot,etc} || err_out 3 "Mountpoint Create Failed"

   # Ensure next-level mountpoints in /var all exist
   mkdir -p "${ALTROOT}"/var/{cache,log,lib/{,rpm},tmp}

   # Ensure /var/run is a link to /run
   if [[ -L /var/run ]]
   then
      (
         cd "${ALTROOT}"/var/ &&
         ln -s ../run run
      )

      if [[ $( readlink "${ALTROOT}/var/run" )$? -eq 1 ]]
      then
         echo "************************************************"
         echo "** WARNING: /var/run is not a symlink to /run **"
         echo "************************************************"
      fi
   fi

   # Mount the boot-root
   echo "Mounting ${BOOTDEV} to ${ALTROOT}/boot"
   mount "${BOOTDEV}" "${ALTROOT}/boot/" || err_out 2 "Mount Failed"
}


##########
## MAIN ##
##########

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

# Ensure that we can find mountable LVM objects
VGNAME=$(lsblk -i -o NAME,TYPE "${LVMDEV}" | grep -w lvm | \
         sed 's/^ *.-//' | cut -d "-" -f 1 | uniq)

# Mount filesystems
if [[ ${#VGNAME} -gt 0 ]]
then

   # Offload mounting LVM2 objects to function
   FlexMount

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
      if [[ ${DEVFSTYP} == ext3 ]] ||
         [[ ${DEVFSTYP} == ext4 ]]
      then
         LABEL=$(e2label "/dev/${PARTS[IDX]}")
      elif [[ ${DEVFSTYP} == xfs ]]
      then
         LABEL=$( xfs_admin -l "/dev/${PARTS[IDX]}" | sed -e 's/"$//' -e 's/^.*"//' )
      else
         err_out 1 "Unable to determine fstype of /dev/${PARTS[IDX]}"
      fi

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
                 /\/ /d
                 /\/boot /d
                 /dev\/xvd/d
                 /dev\/nvme/d
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
