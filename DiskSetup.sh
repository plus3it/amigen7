#!/bin/sh
#
# Script to automate basic setup of CHROOT device
#
#################################################################
PROGNAME=$(basename "$0")
BOOTDEVSZ="500m"

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
   echo $2 > /dev/stderr
   exit $1
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
   dd if=/dev/zero of=${CHROOTDEV} bs=512 count=1000 > /dev/null 2>&1

   # Lay down the base partitions
   parted -s ${CHROOTDEV} -- mklabel msdos mkpart primary ext4 2048s ${BOOTDEVSZ} \
      mkpart primary ext4 ${BOOTDEVSZ} 100% set 2 lvm

   # Create LVM objects
   vgcreate -y ${VGNAME} ${CHROOTDEV}2 || LogBrk 5 "VG creation failed. Aborting!"
   lvcreate -L ${ROOTVOL[1]} -n ${ROOTVOL[0]} ${VGNAME} || LVCSTAT=1
   lvcreate -L ${SWAPVOL[1]} -n ${SWAPVOL[0]} ${VGNAME} || LVCSTAT=1
   lvcreate -L ${HOMEVOL[1]} -n ${HOMEVOL[0]} ${VGNAME} || LVCSTAT=1
   lvcreate -L ${VARVOL[1]} -n ${VARVOL[0]} ${VGNAME} || LVCSTAT=1
   lvcreate -L ${LOGVOL[1]} -n ${LOGVOL[0]} ${VGNAME} || LVCSTAT=1
   lvcreate -l ${AUDVOL[1]} -n ${AUDVOL[0]} ${VGNAME} || LVCSTAT=1

   # Create filesystems
   mkfs -t ext4 -L "${BOOTLABEL}" ${CHROOTDEV}1
   mkfs -t ext4 /dev/${VGNAME}/${ROOTVOL[0]}
   mkfs -t ext4 /dev/${VGNAME}/${HOMEVOL[0]}
   mkfs -t ext4 /dev/${VGNAME}/${VARVOL[0]}
   mkfs -t ext4 /dev/${VGNAME}/${LOGVOL[0]}
   mkfs -t ext4 /dev/${VGNAME}/${AUDVOL[0]}
   mkswap /dev/${VGNAME}/${SWAPVOL[0]}
}

# Partition with no LVM
function CarveBare() {
   # Clear the MBR and partition table
   dd if=/dev/zero of=${CHROOTDEV} bs=512 count=1000 > /dev/null 2>&1

   # Lay down the base partitions
   parted -s ${CHROOTDEV} -- mklabel msdos mkpart primary ext4 2048s ${BOOTDEVSZ} \
      mkpart primary ext4 ${BOOTDEVSZ} 100%

   # Create FS on partitions
   mkfs -t ext4 -L "${BOOTLABEL}" ${CHROOTDEV}1
   mkfs -t ext4 -L "${ROOTLABEL}" ${CHROOTDEV}2
}



######################
## Main program-flow
######################
OPTIONBUFR=`getopt -o b:d:r:v: --long bootlabel:,disk:,rootlabel:,vgname: -n ${PROGNAME} -- "$@"`

eval set -- "${OPTIONBUFR}"

###################################
# Parse contents of ${OPTIONBUFR}
###################################
while [ true ]
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
