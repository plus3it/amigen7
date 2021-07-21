#!/bin/bash
# shellcheck disable=SC2181
#
# Script to set up the chroot'ed /etc/fstab
# - Pass in the name of the EBS device the chroot was built on
#   top of.
#
#################################################################
CHROOT="${AMIGENCHROOT:-/mnt/ec2-root}"
CHROOTDEV=${1:-UNDEF}
CHGRUBDEF="${CHROOT}/etc/default/grub"
DEBUG="${DEBUG:-UNDEF}"
GRUBTMOUT="${GRUBTMOUT:-1}"
FIPSDISABLE="${FIPSDISABLE:-UNDEF}"

# Make interactive-execution more-verbose unless explicitly told not to
if [[ $( tty -s ) -eq 0 ]] && [[ ${DEBUG} == "UNDEF" ]]
then
   DEBUG="true"
fi

# Error handler function
function err_exit {
   local ERRSTR
   local ISNUM
   local SCRIPTEXIT

   ERRSTR="${1}"
   ISNUM='^[0-9]+$'
   SCRIPTEXIT="${2:-1}"

   if [[ ${DEBUG} == true ]]
   then
      # Our output channels
      logger -i -t "${PROGNAME}" -p kern.crit -s -- "${ERRSTR}"
   else
      logger -i -t "${PROGNAME}" -p kern.crit -- "${ERRSTR}"
   fi

   # Only exit if requested exit is numerical
   if [[ ${SCRIPTEXIT} =~ ${ISNUM} ]]
   then
      exit "${SCRIPTEXIT}"
   fi
}


# Print out a basic usage message
function UsageMsg {
   local SCRIPTEXIT
   SCRIPTEXIT="${1:-1}"

   (
      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf '\t%-4s%s\n' '-d' 'Device GRUB2 sets up'
      printf '\t%-4s%s\n' '-h' 'Print this message'
      printf '\t%-4s%s\n' '-t' 'Set GRUB_TIMEOUT value in seconds (default: 1)'
      echo "  GNU long options:"
      printf '\t%-20s%s\n' '--grub-device' 'See "-d" short-option'
      printf '\t%-20s%s\n' '--help' 'See "-h" short-option'
      printf '\t%-20s%s\n' '--grub-timeout' 'See "-t" short-option'
   )
   exit "${SCRIPTEXIT}"
}

######################
## Main program-flow
######################
OPTIONBUFR=$(getopt -o d:ht: --long grub-device:,help,grub-timeout: -n "${PROGNAME}" -- "$@")

eval set -- "${OPTIONBUFR}"

###################################
# Parse contents of ${OPTIONBUFR}
###################################
while true
do
   case "$1" in
      -d|--grub-device)
            case "$2" in
               "")
                  err_exit 1 "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  CHROOTDEV=${2}
                  shift 2;
                  ;;
            esac
            ;;
      -h|--help)
            UsageMsg 0
            ;;
      -t|--grub-timeout)
            case "$2" in
               "")
                  err_exit 1 "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  GRUBTMOUT=${2}
                  shift 2;
                  ;;
            esac
            ;;
      --)
         shift
         break
         ;;
      *)
         err_exit 1 "Internal error!"
         exit 1
         ;;
   esac
done


# Check for arguments
if [[ $# -lt 1 ]]
then
   echo "Missing parameter(s). Aborting..." > /dev/stderr
   exit 1
fi

# Make sure argument is valid
if [[ ! -e /sys/block/$(basename "${CHROOTDEV}") ]]
then
   echo "Invalid block device provided. Aborting..." > /dev/stderr
   exit 1
fi

# Shouldn't need this, but the RPM seems to be broken (20160315)
if [[ ! -f ${CHGRUBDEF} ]]
then
   printf "The grub2-tools RPM (vers. "
   # shellcheck disable=SC2059
   printf "$(rpm -q grub2-tools --qf '%{version}-%{release}\n')) "
   printf "was faulty. Manufacturing a %s.\n" "${CHGRUBDEF}"

   (
    printf "GRUB_TIMEOUT=%s\n" "${GRUBTMOUT}"
    # shellcheck disable=2059
    printf "GRUB_DISTRIBUTOR=\"$(sed 's, release .*$,,g' /etc/system-release)\"\n"
    printf "GRUB_DEFAULT=saved\n"
    printf "GRUB_DISABLE_SUBMENU=true\n"
    printf "GRUB_DISABLE_LINUX_UUID=true\n"
    printf "GRUB_DISABLE_RECOVERY=\"true\"\n"
    printf "GRUB_TERMINAL_OUTPUT=\"console\"\n"
    # Set GRUB2 vconsole output behavior
    printf "GRUB_CMDLINE_LINUX=\"crashkernel=auto vconsole.keymap=us "
    printf "vconsole.font=latarcyrheb-sun16 console=tty0 "
    printf "console=ttyS0,115200n8 "
    # Disable systemd's predictable network interface naming behavior
    printf "net.ifnames=0 "
    # Enable FIPS mode ...and make it accept the /boot partition
    case "${FIPSDISABLE}" in
       true|TRUE|1|on)
          printf "fips=0 boot=LABEL=/boot\"\n"
          ;;
       UNDEF|''|false|FALSE|0)
          printf "fips=1 boot=LABEL=/boot\"\n"
          ;;
    esac
   ) > "${CHGRUBDEF}"

   if [[ $? -ne 0 ]]
   then
      echo "Failed..." >> /dev/stderr
      exit 1
   fi
fi

# Create and install a GRUB2 config file (etc.)
chroot "${CHROOT}" /bin/bash -c "/sbin/grub2-install ${CHROOTDEV}"
chroot "${CHROOT}" /bin/bash -c "/sbin/grub2-mkconfig  > /boot/grub2/grub.cfg"
CHROOTKRN=$(chroot "$CHROOT" rpm --qf '%{version}-%{release}.%{arch}\n' -q kernel)
chroot "${CHROOT}" dracut -fv "/boot/initramfs-${CHROOTKRN}.img" "${CHROOTKRN}"
