#!/bin/bash
# shellcheck disable=SC2181
#
# Configure components within the chroot
# * Set system-wide TZ to match TIMEZONE value (UTC)
# * Enable /tmp as tmpfs
# * Configure ntp servers if a ntp_hosts.txt is found in
#   the directory from which the script is exec'ed
# * Enable ntpd client-service - if server is defined in
#   ntp.conf
# * Ensure that selinux policy-definitions are in place
# * Process a secondary localization script if the
#   secondary-script the environmental-variable
#   (${LOCALSCRIPT}) is set and points to a valid
#   location.
#
#####################################
PROGNAME=$(basename "$0")
CHROOT="${AMIGENCHROOT:-/mnt/ec2-root}"
DEBUG="${DEBUG:-UNDEF}"
EXECIT=${LOCALSCRIPT:-UNDEF}
NTPCONF="${CHROOT}/etc/ntp.conf"
CLOUDCF="${CHROOT}/etc/cloud/cloud.cfg"
TIMEZONE="${AMIGENTIMEZONE:-UTC}"

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
      printf '\t%-4s%s\n' '-f' 'Filesystem-type of chroot-devs (e.g., "xfs")'
      printf '\t%-4s%s\n' '-h' 'Print this message'
      printf '\t%-4s%s\n' '-m' 'Where chroot-dev is mounted (default: "/mnt/ec2-root")'
      printf '\t%-4s%s\n' '-z' 'Initial timezone of build-target (default: "UTC")'
      echo "  GNU long options:"
      printf '\t%-20s%s\n' '--fstype' 'See "-f" short-option'
      printf '\t%-20s%s\n' '--help' 'See "-h" short-option'
      printf '\t%-20s%s\n' '--mountpoint' 'See "-m" short-option'
      printf '\t%-20s%s\n' '--no-tmpfs' 'Disable /tmp as tmpfs behavior'
      printf '\t%-20s%s\n' '--timezone' 'See "-z" short-option'
   )
   exit "${SCRIPTEXIT}"
}

######################
## Main program-flow
######################
OPTIONBUFR=$( getopt \
   -o hm:z: \
   --long help,mountpoint:,timezone \
   -n "${PROGNAME}" -- "$@")

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
      -m|--mountpoint)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  CHROOT=${2}
                  shift 2;
                  ;;
            esac
            ;;
      -z|--timezone)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  TIMEZONE=${2}
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




# Ensure key-based logins are enabled
sed -i -e '/^ssh_pwauth/s/0$/1/' "${CLOUDCF}"

# Set AMI TimeZone
rm "${CHROOT}/etc/localtime"
cp "${CHROOT}/usr/share/zoneinfo/${TIMEZONE}" "${CHROOT}/etc/localtime"
if [[ $? -eq 0 ]]
then
   echo "AMI TZ set to \"${TIMEZONE}\""
else
   echo "Failed to set TZ to \"${TIMEZONE}\"" > /dev/stderr
fi

# Ensure ntpd service is enabled and configured
if [[ -s ${NTPCONF} ]]
then
   # Append an NTP server-list to existing config file
   if [ -s ntp_hosts.txt ]
   then
      sed -i 's/^server /# &/' "${NTPCONF}"
      cat ntp_hosts.txt >> "${NTPCONF}"
   fi

   # Only enable NTPD if a "server" line is found
   if [[ $(grep -q "^server" "${NTPCONF}")$? -eq 0 ]]
   then
      chroot "${CHROOT}" /bin/sh -c "/sbin/chkconfig ntpd on"
   else
      printf "%s does not exist or does not " "${NTPCONF}" > /dev/stderr
      printf "have a \"server\" defined.\n" > /dev/stderr
      printf "NTPD not configured/enabled.\n" > /dev/stderr
   fi
fi

# Ensure that tmp.mount Service is enabled
chroot "${CHROOT}" /bin/systemctl unmask tmp.mount
chroot "${CHROOT}" /bin/systemctl enable tmp.mount

# Ensure that SELinux policy files are installed
chroot "${CHROOT}" /bin/sh -c "(rpm -q --scripts selinux-policy-targeted | \
   sed -e '1,/^postinstall scriptlet/d' | \
   sed -e '1i #!/bin/sh') > /tmp/selinuxconfig.sh ; \
   sh /tmp/selinuxconfig.sh 1"

# Ensure that firewalld will work in drop mode...
printf "Adding firewalld rules... "
chroot "${CHROOT}" /bin/sh -c "(
      firewall-offline-cmd --direct --add-rule ipv4 filter INPUT_direct 10 -m state --state RELATED,ESTABLISHED -m comment --comment 'Allow related and established connections' -j ACCEPT
      firewall-offline-cmd --direct --add-rule ipv4 filter INPUT_direct 20 -i lo -j ACCEPT
      firewall-offline-cmd --direct --add-rule ipv4 filter INPUT_direct 30 -d 127.0.0.0/8 '!' -i lo -j DROP
      firewall-offline-cmd --direct --add-rule ipv4 filter INPUT_direct 50 -p tcp -m tcp --dport 22 -j ACCEPT
   )" && echo "Success!" || echo "Encountered errors."

## Note: add `firewall-offline-cmd --set-default-zone=drop` to the above ##
## to set the default AMI/instance posture to "drop". As written, the    ##
## above only adds "safeties" to the AMI/instance in case someone        ##
## changes the default-zone from "public" to "drop" (or other            ##
## more-restrictive-than-public firewalld posture).                      ##
###########################################################################

# Execute any localizations if a valid script-location is
# passed as a shell-env
if [[ ${EXECIT} = "UNDEF" ]]
then
   echo "No content-localization requested..."
elif [[ -s ${EXECIT} ]]
then
   echo "Attempting to execut ${EXECIT}"
   bash "${EXECIT}"
else
   echo "Content-localization file is null: will not attempt execution."
fi

