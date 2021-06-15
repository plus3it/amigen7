#!/bin/bash
# shellcheck disable=SC2015,SC2207
#
# Setup/mount chroot'ed volumes/partitions
# * Takes the dev-path hosting the /boot and LVM partitions as argument
#
#######################################################################
PROGNAME=$(basename "$0")
CHROOTDEV=${1:-UNDEF}
CHROOTMNT="${AMIGENCHROOT:-/mnt/ec2-root}"
FSTYPE="${DEFFSTYPE:-ext4}"
DEFGEOMARR=(
   /:rootVol:4
   swap:swapVol:2
   /home:homeVol:1
   /var:varVol:2
   /var/log:logVol:2
   /var/log/audit:auditVol:100%FREE
)
DEFGEOMSTR="${DEFGEOMSTR:-$( IFS=$',' ; echo "${DEFGEOMARR[*]}" )}"
GEOMETRYSTRING="${DEFGEOMSTR}"

if [[ ${CHROOTDEV} =~ /dev/nvme ]]
then
   PARTPRE="p"
else
   PARTPRE=""
fi




# Print out a basic usage message
function UsageMsg {
   local SCRIPTEXIT
   local PART
   SCRIPTEXIT="${1:-1}"

   (
      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf '\t%-4s%s\n' '-d' 'Device to contain the OS partition(s) (e.g., "/dev/xvdf")'
      printf '\t%-4s%s\n' '-f' 'Filesystem-type used chroot-dev device(s) (default: "ext4")'
      printf '\t%-4s%s\n' '-h' 'Print this message'
      printf '\t%-4s%s\n' '-m' 'Where to mount chroot-dev (default: "/mnt/ec2-root")'
      printf '\t%-4s%s\n' '-p' 'Comma-delimited string of colon-delimited partition-specs'
      printf '\t%-6s%s\n' '' 'Default layout:'
      for PART in ${DEFGEOMARR[*]}
      do
         printf '\t%-8s%s\n' '' "${PART}"
      done
      echo "  GNU long options:"
      printf '\t%-20s%s\n' '--disk' 'See "-d" short-option'
      printf '\t%-20s%s\n' '--fstype' 'See "-f" short-option'
      printf '\t%-20s%s\n' '--help' 'See "-h" short-option'
      printf '\t%-20s%s\n' '--mountpoint' 'See "-m" short-option'
      printf '\t%-20s%s\n' '--partition-string' 'See "-p" short-option'
   )
   exit "${SCRIPTEXIT}"
}

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
      if [[ ! -d ${CHROOTMNT}/${MOUNTPT} ]]
      then
          install -dDm 000755 "${CHROOTMNT}/${MOUNTPT}"
      fi

      # Mount the filesystem
      if [[ ${MOUNTPT} == /* ]]
      then
         echo "Mounting '${CHROOTMNT}${MOUNTPT}'..."
         mount -t "${FSTYPE}" "/dev/${VGNAME}/${MOUNTINFO[${MOUNTPT}]//:*/}" \
           "${CHROOTMNT}${MOUNTPT}" || \
             err_out 1 "Unable to mount /dev/${VGNAME}/${MOUNTINFO[${MOUNTPT}]//:*/}"
      else
         echo "Skipping '${MOUNTPT}'..."
      fi
   done

   # Ensure next-level mountpoints in / all exist
   mkdir -p "${CHROOTMNT}"/{var,opt,home,boot,etc} || err_out 3 "Mountpoint Create Failed"

   # Ensure next-level mountpoints in /var all exist
   mkdir -p "${CHROOTMNT}"/var/{cache,log,lib/{,rpm},tmp}

   # Ensure /var/run is a link to /run
   if [[ -L /var/run ]]
   then
      (
         cd "${CHROOTMNT}"/var/ &&
         ln -s ../run run
      )

      if [[ $( readlink "${CHROOTMNT}/var/run" )$? -eq 1 ]]
      then
         echo "************************************************"
         echo "** WARNING: /var/run is not a symlink to /run **"
         echo "************************************************"
      fi
   fi

   # Mount the boot-root
   echo "Mounting ${BOOTDEV} to ${CHROOTMNT}/boot"
   mount "${BOOTDEV}" "${CHROOTMNT}/boot/" || err_out 2 "Mount Failed"
}


##########
## MAIN ##
##########

OPTIONBUFR=$( getopt \
   -o d:f:hm:p: \
   --long disk:,fstype:,help,mountpoint:,partition-string: \
   -n "${PROGNAME}" -- "$@")

eval set -- "${OPTIONBUFR}"

###################################
# Parse contents of ${OPTIONBUFR}
###################################
while true
do
   case "$1" in
      -d|--disk)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  CHROOTDEV="${2}"
                  shift 2;
                  ;;
            esac
            ;;
      -f|--fstype)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  FSTYPE="${2}"
                  if [[ $( grep -qw "${FSTYPE}" <<< "${VALIDFSTYPES[*]}" ) -ne 0 ]]
                  then
                     err_exit "Invalid fstype [${FSTYPE}] requested"
                  fi
                  shift 2;
                  ;;
            esac
            ;;
      -h|--help)
            UsageMsg 0
            ;;
      -m|--mountpoint)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  CHROOTMNT=${2}
                  shift 2;
                  ;;
            esac
            ;;
      -p|--partition-string)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  GEOMETRYSTRING=${2}
                  shift 2;
                  ;;
            esac
            ;;
      --)
         shift
         break
         ;;
      *)
         err_exit "Internal error!"
         exit 1
         ;;
   esac
done



BOOTDEV=${CHROOTDEV}${PARTPRE}1
LVMDEV=${CHROOTDEV}${PARTPRE}2

# Can't do anything if we don't have an EBS to operate on
if [[ ${CHROOTDEV} = UNDEF ]]
then
   err_out 1 "Must supply name of device to use (e.g., /dev/xvdg)"
fi

if [ -d "${CHROOTMNT}" ]
then
   echo "Found ${CHROOTMNT}: proceeding..."
elif [ -e "${CHROOTMNT}" ] && [ ! -d "${CHROOTMNT}" ]
then
   err_out 1 "Found ${CHROOTMNT} but it's not usable as mount-point"
else
   printf "Requested chroot [%s] not found. Attempting to create... " "${CHROOTMNT}"
   install -d -m 0755 "${CHROOTMNT}" || err_out 1 "Failed to create ${CHROOTMNT}."
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
      if [[ ${FSTYPE} == ext3 ]] ||
         [[ ${FSTYPE} == ext4 ]]
      then
         LABEL=$(e2label "/dev/${PARTS[IDX]}")
      elif [[ ${FSTYPE} == xfs ]]
      then
         LABEL=$( xfs_admin -l "/dev/${PARTS[IDX]}" | sed -e 's/"$//' -e 's/^.*"//' )
      else
         err_out 1 "Unable to determine fstype of /dev/${PARTS[IDX]}"
      fi

      # Ensure mount-point exists
      if [[ ! -d ${CHROOTMNT}${MNTPTS[IDX]} ]]
      then
         mkdir -p "${CHROOTMNT}${MNTPTS[IDX]}"
      fi

      # Mount partition by label
      mount LABEL="${LABEL}" "${CHROOTMNT}${MNTPTS[IDX]}"
   done

fi


# Prep for loopback mounts
mkdir -p "${CHROOTMNT}"/{proc,sys,dev/{pts,shm}}

# Create base dev-nodes
mknod -m 600 "${CHROOTMNT}"/dev/console c 5 1
mknod -m 666 "${CHROOTMNT}"/dev/null c 1 3
mknod -m 666 "${CHROOTMNT}"/dev/zero c 1 5
mknod -m 666 "${CHROOTMNT}"/dev/random c 1 8
mknod -m 666 "${CHROOTMNT}"/dev/urandom c 1 9
mknod -m 666 "${CHROOTMNT}"/dev/tty c 5 0
mknod -m 666 "${CHROOTMNT}"/dev/ptmx c 5 2
chown root:tty "${CHROOTMNT}"/dev/ptmx


# Bind-mount everything else
BINDSOURCES=( $(grep -v "${CHROOTMNT}" /proc/mounts | sed '{
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
   if [[ ! -d ${CHROOTMNT}${MOUNT} ]]
   then
      mkdir -p "${CHROOTMNT}${MOUNT}" && \
         echo "Creating ${CHROOTMNT}${MOUNT}" || break
   fi
   echo "Bind-mounting ${MOUNT} to ${CHROOTMNT}${MOUNT}"
   mount -o bind "${MOUNT}" "${CHROOTMNT}${MOUNT}"
done
