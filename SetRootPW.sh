#!/bin/bash
# set -euo pipefail
#
# shellcheck disable=SC2015
#
# Simple script to enable maintenance-login before sealing up the template
#
######################################################################
PROGNAME="$( basename "${0}" )"
CHROOT="${CHROOT:-/mnt/ec2-root}"
ROOTPWSTRING="${PWSTRING:-UNDEF}"
MAINTUSER="${MAINTUSER:-root}"


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
   local PART
   SCRIPTEXIT="${1:-1}"

   (
      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf '\t%-4s%s\n' '-h' 'Print this message'
      printf '\t%-4s%s\n' '-m' 'Template maintenance user (default: "root")'
      printf '\t%-4s%s\n' '-p' 'Password to assign to template maintenance user'
      printf '\t%-6s%s\n' '' 'Default layout:'
      for PART in ${DEFGEOMARR[*]}
      do
         printf '\t%-8s%s\n' '' "${PART}"
      done
      echo "  GNU long options:"
      printf '\t%-20s%s\n' '--help' 'See "-h" short-option'
      printf '\t%-20s%s\n' '--maintuser' 'See "-m" short-option'
      printf '\t%-20s%s\n' '--password' 'See "-p" short-option'
   )
   exit "${SCRIPTEXIT}"
}

function SetPassString {
   printf "Setting password for %s... " "${MAINTUSER}"
   echo "${ROOTPWSTRING}" | chroot "${CHROOT}" /bin/passwd --stdin "${MAINTUSER}" && \
     echo "Success" || err_exit "Failed setting password for ${MAINTUSER}" 1

}

function AllowRootSsh {
   local SSHDCFGFILE
   local CFGITEM

   SSHDCFGFILE="${CHROOT}/etc/ssh/sshd_config"
   CFGITEM="PermitRootLogin"

   printf "Allow remote-login for root... "
   if [[ $( grep -q "^${CFGITEM}" "${SSHDCFGFILE}" )$? -eq 0 ]]
   then
      sed -i "/^${CFGITEM}/s/[ 	][ 	]*.*$/ yes/" "${SSHDCFGFILE}" && \
        echo "Change ${CFGITEM} value in ${SSHDCFGFILE}" 0 || \
        err_exit "Failed changing ${CFGITEM} value in ${SSHDCFGFILE}" 1
   else
      echo "PermitRootLogin yes" > "${SSHDCFGFILE}" && \
        echo "Added ${CFGITEM} to ${SSHDCFGFILE}" 0 || \
        err_exit "Failed adding ${CFGITEM} to ${SSHDCFGFILE}" 1
   fi
}

function EnableProvUser {

   # Create maintenance user
   printf 'Creating %s in chroot [%s]... ' "${MAINTUSER}" "${CHROOT}"
   chroot "${CHROOT}" useradd -c "Maintenance User Account" -m \
     -s /bin/bash "${MAINTUSER}" && echo "Success!" || \
     err_exit "Failed creating ${MAINTUSER}" 1

   # Give maintenance user privileges
   printf 'Adding %s to sudoers... ' "${MAINTUSER}"
   printf '%s\tALL=(ALL)\tNOPASSWD:ALL\n' "${MAINTUSER}" > \
     "${CHROOT}/etc/sudoers.d/user_${MAINTUSER}" && echo "Success!" || \
     err_exit "Failed adding ${MAINTUSER} to sudoers" 1

   # Set password
   SetPassString
}



######################
## Main program-flow
######################
OPTIONBUFR=$(getopt -o hm:p: --long help,maintuser:,password: -n "${PROGNAME}" -- "$@")

eval set -- "${OPTIONBUFR}"

###################################
# Parse contents of ${OPTIONBUFR}
###################################
while true
do
   case "$1" in
      -h|--help)
         UsageMsg 0
         ;;
      -m|--maintuser)
         case "$2" in
            "")
               err_exit "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               MAINTUSER=${2}
               shift 2;
               ;;
         esac
         ;;
      -p|--password)
         case "$2" in
            "")
               err_exit "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               ROOTPWSTRING=${2}
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


# Exit if password not passed
if [[ ${ROOTPWSTRING} == UNDEF ]]
then
   err_exit "No password string passed to script. ABORTING!" 1
fi

# Configure for direct-root or sudo-to-root
if [[ ${MAINTUSER} == root ]]
then
   # Set root's password
   SetPassString

   # Set up SSH to allow direct-root
   AllowRootSsh
else
   EnableProvUser
fi
