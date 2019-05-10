#!/bin/sh
# shellcheck disable=SC2181
#
# Script to automate basic setup of CHROOT device
#
#################################################################
PROGNAME=$(basename "$0")
BOOTDEVSZ="500m"
FSTYPE="${FSTYPE:-ext4}"

# Error-logging
function err_exit {
   echo "${1}" > /dev/stderr
   logger -t "${PROGNAME}" -p kern.crit "${1}"
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

function LogBrk() {
   echo "${2}" > /dev/stderr
   exit "${1}"
}

# Partition as LVM
function CarveLVM() {
   local ROOTVOL=(rootVol 4g)
   local SWAPVOL=(swapVol 2g)
   local HOMEVOL=(homeVol 1g)
   local VARVOL=(varVol 2g)
   local LOGVOL=(logVol 2g)
   local AUDVOL=(auditVol 100%FREE)

   # Clear the MBR and partition table
   dd if=/dev/zero of="${CHROOTDEV}" bs=512 count=1000 > /dev/null 2>&1

   # Lay down the base partitions
   parted -s "${CHROOTDEV}" -- mklabel msdos mkpart primary "${FSTYPE}" 2048s ${BOOTDEVSZ} \
      mkpart primary "${FSTYPE}" ${BOOTDEVSZ} 100% set 2 lvm

   # Stop/umount boot device, in case parted/udev/systemd managed to remount it
  systemctl stop boot.mount || true

   # Create LVM objects
   LVCSTAT=0
   # Let's only attempt this if we're a secondary EBS
   if [[ ${CHROOTDEV} == /dev/xvda ]] || [[ ${CHROOTDEV} == /dev/nvme0n1 ]]
   then
      echo "Skipping explicit pvcreate opertion... " 
   else
      pvcreate "${CHROOTDEV}${PARTPRE}2" || LogBrk 5 "PV creation failed. Aborting!"
   fi
   vgcreate -y "${VGNAME}" "${CHROOTDEV}${PARTPRE}2" || LogBrk 5 "VG creation failed. Aborting!"
   lvcreate --yes -W y -L "${ROOTVOL[1]}" -n "${ROOTVOL[0]}" "${VGNAME}" || LVCSTAT=1
   lvcreate --yes -W y -L "${SWAPVOL[1]}" -n "${SWAPVOL[0]}" "${VGNAME}" || LVCSTAT=1
   lvcreate --yes -W y -L "${HOMEVOL[1]}" -n "${HOMEVOL[0]}" "${VGNAME}" || LVCSTAT=1
   lvcreate --yes -W y -L "${VARVOL[1]}" -n "${VARVOL[0]}" "${VGNAME}" || LVCSTAT=1
   lvcreate --yes -W y -L "${LOGVOL[1]}" -n "${LOGVOL[0]}" "${VGNAME}" || LVCSTAT=1
   lvcreate --yes -W y -l "${AUDVOL[1]}" -n "${AUDVOL[0]}" "${VGNAME}" || LVCSTAT=1

   if [[ ${LVCSTAT} = 1 ]]
   then
      echo "Failed creating one or more volumes. Aborting"
      exit 1
   fi

   # Gather info to diagnose seeming /boot race condition
   if [[ $(grep -q "${BOOTLABEL}" /proc/mounts)$? -eq 0 ]]
   then
     tail -n 100 /var/log/messages
     sleep 3
   fi

   # Stop/umount boot device, in case parted/udev/systemd managed to remount it
   # again.
  systemctl stop boot.mount || true

   # Create filesystems
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" -L "${BOOTLABEL}" "${CHROOTDEV}${PARTPRE}1" || err_exit "Failure creating filesystem - /boot"
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" "/dev/${VGNAME}/${ROOTVOL[0]}" || err_exit "Failure creating filesystem - /"
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" "/dev/${VGNAME}/${HOMEVOL[0]}" || err_exit "Failure creating filesystem - /home"
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" "/dev/${VGNAME}/${VARVOL[0]}" || err_exit "Failure creating filesystem - /var"
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" "/dev/${VGNAME}/${LOGVOL[0]}" || err_exit "Failure creating filesystem - /var/log"
   mkfs -t "${FSTYPE}" "${MKFSFORCEOPT}" "/dev/${VGNAME}/${AUDVOL[0]}" || err_exit "Failure creating filesystem - /var/log/audit"
   mkswap "/dev/${VGNAME}/${SWAPVOL[0]}"

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
function CarveBare() {
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
OPTIONBUFR=$(getopt -o b:d:f:r:v: --long bootlabel:,disk:,fstype:,rootlabel:,vgname: -n "${PROGNAME}" -- "$@")

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
