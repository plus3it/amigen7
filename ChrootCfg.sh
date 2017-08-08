#!/bin/bash
# shellcheck disable=SC2181
#
# Configure components within the chroot
# * Set system-wide TZ to match TIMEZON value (UTC)
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
CHROOT="${CHROOT:-/mnt/ec2-root}"
EXECIT=${LOCALSCRIPT:-UNDEF}
NTPCONF="${CHROOT}/etc/ntp.conf"
CLOUDCF="${CHROOT}/etc/cloud/cloud.cfg"
TIMEZON="UTC"

# Ensure key-based logins are enabled
sed -i -e '/^ssh_pwauth/s/0$/1/' "${CLOUDCF}"

# Set AMI TimeZone
rm "${CHROOT}/etc/localtime"
cp "${CHROOT}/usr/share/zoneinfo/${TIMEZON}" "${CHROOT}/etc/localtime"
if [[ $? -eq 0 ]]
then
   echo "AMI TZ set to \"${TIMEZON}\""
else
   echo "Failed to set TZ to \"${TIMEZON}\"" > /dev/stderr
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

