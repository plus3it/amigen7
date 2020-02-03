#!/bin/bash
# shellcheck disable=SC2181,SC2236
#
# Script to automate basic setup of CHROOT device
#
#################################################################
PROGNAME=$(basename "$0")
BOOTDEVSZ="500m"
FSTYPE="${FSTYPE:-ext4}"

# Function-abort hooks
trap "exit 1" TERM
export TOP_PID=$$

# Error-logging
function err_exit {
   echo "${1}" > /dev/stderr
   logger -t "${PROGNAME}" -p kern.crit "${1}"
   exit 1
}

# Print out a basic usage message
function UsageMsg {
   (
      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf "\t-b <BOOT_LABEL>\n"
      printf "\t-d <BOOT_DEV_PATH>\n"
      printf "\t-f <FSTYPE>\n"
      printf "\t-p <PARTITION_STRING>\n"
      printf "\t-r <ROOT_FS_LABEL>\n"
      printf "\t-v <ROOT_VG_NAME>\n"
      echo "  GNU long options:"
      printf "\t--bootlabel <BOOT_LABEL>\n"
      printf "\t--disk <BOOT_DEV_PATH>\n"
      printf "\t--fstype <FSTYPE>\n"
      printf "\t--partitioning <PARTITION_STRING>\n"
      printf "\t--rootlabel <ROOT_FS_LABEL>\n"
      printf "\t--vgname <ROOT_VG_NAME>\n"
   )
   exit 1
}

# Check for arguments
if [[ $# -lt 1 ]]
then
   (
    printf "Missing parameter(s). Valid flags/parameters are:\n"
    printf "\t-b|--bootlabel: FS-label applied to '/boot' filesystem\n"
    printf "\t-d|--disk: dev-path to disk to be partitioned\n"
    printf "\t-r|--rootlabel: FS-label to apply to '/' filesystem (no LVM in use)\n"
    printf "\t-v|--vgname: LVM2 Volume-Group name for root volumes\n"
    printf "Aborting...\n"
   ) > /dev/stderr
   exit 1
fi

function LogBrk {
   echo "${2}" > /dev/stderr
   exit "${1}"
}

# Partition as LVM
function CarveLVM {
   local ITER
   local MOUNTPT
   local PARTITIONARRAY
   local PARTITIONSTR
   local VOLFLAG
   local VOLNAME
   local VOLSIZE

   # Whether to use flag-passed partition-string or default values
   if [ -z ${GEOMETRYSTRING+x} ]
   then
       # This is fugly but might(??) be easier for others to follow/update
       PARTITIONSTR="/:rootVol:4"
       PARTITIONSTR+=",swap:swapVol:2"
       PARTITIONSTR+=",/home:homeVol:1"
       PARTITIONSTR+=",/var:varVol:2"
       PARTITIONSTR+=",/var/log:logVol:2"
       PARTITIONSTR+=",/var/log/audit:auditVol:100%FREE"
   else
       PARTITIONSTR="${GEOMETRYSTRING}"
   fi

   # Convert ${PARTITIONSTR} to iterable array
   IFS=',' read -r -a PARTITIONARRAY <<< "${PARTITIONSTR}"

   # Clear the MBR and partition table
   dd if=/dev/zero of="${CHROOTDEV}" bs=512 count=1000 > /dev/null 2>&1

   # Lay down the base partitions
   parted -s "${CHROOTDEV}" -- mklabel msdos mkpart primary "${FSTYPE}" 2048s ${BOOTDEVSZ} \
      mkpart primary "${FSTYPE}" ${BOOTDEVSZ} 100% set 2 lvm

   # Gather info to diagnose seeming /boot race condition
   if [[ $(grep -q "${BOOTLABEL}" /proc/mounts)$? -eq 0 ]]
   then
     tail -n 100 /var/log/messages
     sleep 3
   fi

   # Stop/umount boot device, in case parted/udev/systemd managed to remount it
   # again.
   systemctl stop boot.mount || true

   # Create /boot filesystem
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" -L "${BOOTLABEL}" \
     "${CHROOTDEV}${PARTPRE}1" || \
       err_exit "Failure creating filesystem - /boot"

   ## Create LVM objects

   # Let's only attempt this if we're a secondary EBS
   if [[ ${CHROOTDEV} == /dev/xvda ]] || [[ ${CHROOTDEV} == /dev/nvme0n1 ]]
   then
      echo "Skipping explicit pvcreate opertion... " 
   else
      pvcreate "${CHROOTDEV}${PARTPRE}2" || LogBrk 5 "PV creation failed. Aborting!"
   fi

   # Create root VolumeGroup
   vgcreate -y "${VGNAME}" "${CHROOTDEV}${PARTPRE}2" || LogBrk 5 "VG creation failed. Aborting!"

   # Create LVM2 volume-objects by iterating ${PARTITIONARRAY}
   ITER=0
   while [[ ${ITER} -lt ${#PARTITIONARRAY[*]} ]]
   do
      MOUNTPT="$( cut -d ':' -f 1 <<< "${PARTITIONARRAY[${ITER}]}")"
      VOLNAME="$( cut -d ':' -f 2 <<< "${PARTITIONARRAY[${ITER}]}")"
      VOLSIZE="$( cut -d ':' -f 3 <<< "${PARTITIONARRAY[${ITER}]}")"

      # Create LVs
      if [[ ${VOLSIZE} =~ FREE ]]
      then
         # Make sure 'FREE' is given as last list-element
         if [[ $(( ITER += 1 )) -eq ${#PARTITIONARRAY[*]} ]]
         then
            VOLFLAG="-l"
            VOLSIZE="100%FREE"
         else
            echo "Using 'FREE' before final list-element. Aborting..."
            kill -s TERM " ${TOP_PID}"
         fi
      else
         VOLFLAG="-L"
         VOLSIZE+="g"
      fi
      lvcreate --yes -W y "${VOLFLAG}" "${VOLSIZE}" -n "${VOLNAME}" "${VGNAME}" || \
        err_exit "Failure creating LVM2 volume '${VOLNAME}'"

      # Create FSes on LVs
      if [[ ${MOUNTPT} == swap ]]
      then
         mkswap "/dev/${VGNAME}/${VOLNAME}"
      else
         mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" "/dev/${VGNAME}/${VOLNAME}" \
            || err_exit "Failure creating filesystem for '${MOUNTPT}'"
      fi

      (( ITER+=1 ))
   done

   # shellcheck disable=SC2053
   if [[ ${FSTYPE} == ext3 ]] || [[ ${FSTYPE} == ext4 ]]
   then
      if [[ $( e2label "${CHROOTDEV}${PARTPRE}1" ) != ${BOOTLABEL} ]]
      then
         e2label "${CHROOTDEV}${PARTPRE}1" "${BOOTLABEL}" || \
            err_exit "Failed to apply desired label to ${CHROOTDEV}${PARTPRE}1"
      fi
   elif [[ ${FSTYPE} == xfs ]]
   then
      if [[ $( xfs_admin -l "${CHROOTDEV}${PARTPRE}1"  | sed -e 's/"$//' -e 's/^.*"//' ) != ${BOOTLABEL} ]]
      then
         xfs_admin -L "${CHROOTDEV}${PARTPRE}1" "${BOOTLABEL}" || \
            err_exit "Failed to apply desired label to ${CHROOTDEV}${PARTPRE}1"
      fi
   else
      err_exit "Unrecognized fstype [${FSTYPE}] specified. Aborting... "
   fi

}

# Partition with no LVM
function CarveBare {
   # Clear the MBR and partition table
   dd if=/dev/zero of="${CHROOTDEV}" bs=512 count=1000 > /dev/null 2>&1

   # Lay down the base partitions
   parted -s "${CHROOTDEV}" -- mklabel msdos mkpart primary "${FSTYPE}" 2048s "${BOOTDEVSZ}" \
      mkpart primary "${FSTYPE}" ${BOOTDEVSZ} 100%

   # Create FS on partitions
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" -L "${BOOTLABEL}" "${CHROOTDEV}${PARTPRE}1"
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" -L "${ROOTLABEL}" "${CHROOTDEV}${PARTPRE}2"
}



######################
## Main program-flow
######################
OPTIONBUFR=$(getopt -o b:d:f:hp:r:v: --long bootlabel:,disk:,fstype:,help,partitioning:,rootlabel:,vgname: -n "${PROGNAME}" -- "$@")

eval set -- "${OPTIONBUFR}"

###################################
# Parse contents of ${OPTIONBUFR}
###################################
while true
do
   case "$1" in
      -b|--bootlabel)
            case "$2" in
               "")
                  LogBrk 1 "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  BOOTLABEL=${2}
                  shift 2;
                  ;;
            esac
            ;;
      -d|--disk)
            case "$2" in
               "")
                  LogBrk 1 "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  CHROOTDEV=${2}
                  shift 2;
                  ;;
            esac
            ;;
      -f|--fstype)
            case "$2" in
               "")
                  LogBrk 1 "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               ext3|ext4)
                  FSTYPE=${2}
                  MKFSFORCEOPT="-F"
                  shift 2;
                  ;;
               xfs)
                  FSTYPE=${2}
                  MKFSFORCEOPT="-f"
                  shift 2;
                  ;;
               *)
                  LogBrk 1 "Error: unrecognized/unsupported FSTYPE. Aborting..."
                  shift 2;
                  exit 1
                  ;;
            esac
            ;;
      -h|--help)
            UsageMsg
            ;;
      -p|--partitioning)
            case "$2" in
               "")
                  LogBrk 1"Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  GEOMETRYSTRING=${2}
                  shift 2;
                  ;;
            esac
            ;;
      -r|--rootlabel)
            case "$2" in
               "")
                  LogBrk 1"Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  ROOTLABEL=${2}
                  shift 2;
                  ;;
            esac
            ;;
      -v|--vgname)
            case "$2" in
               "")
                  LogBrk 1 "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
               VGNAME=${2}
                  shift 2;
                  ;;
            esac
            ;;
      --)
         shift
         break
         ;;
      *)
         LogBrk 1 "Internal error!"
         exit 1
         ;;
   esac
done

# See if our carve-target is an NVMe
if [[ ${CHROOTDEV} =~ /dev/nvme ]]
then
   PARTPRE="p"
else
   PARTPRE=""
fi

# Ensure BOOTLABEL has been specified
if [[ -z ${BOOTLABEL+xxx} ]]
then
   LogBrk 1 "Cannot continue without 'bootlabel' being specified. Aborting..."
elif [[ ! -z ${ROOTLABEL+xxx} ]] && [[ ! -z ${VGNAME+xxx} ]]
then
   LogBrk 1 "The 'rootlabel' and 'vgname' arguments are mutually exclusive. Exiting."
elif [[ -z ${ROOTLABEL+xxx} ]] && [[ ! -z ${VGNAME+xxx} ]]
then
   CarveLVM
elif [[ ! -z ${ROOTLABEL+xxx} ]] && [[ -z ${VGNAME+xxx} ]]
then
   CarveBare
fi
