#!/bin/bash
#
# Configure components within the chroot
#
#####################################
CHROOT="${CHROOT:-/mnt/ec2-root}"
TARGDEV="${1:-UNDEF}"
NTPCONF="${CHROOT}/etc/ntp.conf"
CLOUDCF="${CHROOT}/etc/cloud/cloud.cfg"
TIMEZON="UTC"

# Ensure key-based logins are enabled
sed -i -e '/^ssh_pwauth/s/0$/1/' ${CLOUDCF}

# Set AMI TimeZone
rm ${CHROOT}/etc/localtime
cp ${CHROOT}/usr/share/zoneinfo/${TIMEZON} ${CHROOT}/etc/localtime
if [[ $? -eq 0 ]]
then
   echo "AMI TZ set to \"${TIMEZON}\""
else
   echo "Failed to set TZ to \"${TIMEZON}\"" > /dev/stderr
fi

# Ensure ntpd service is enabled and configured
if [ -s ${NTPCONF} ]
then
   # Append an NTP server-list to existing config file
   if [ -s ntp_hosts.txt ]
   then
      sed -i 's/^server /# &/' ${NTPCONF}
      cat ntp_hosts.txt >> ${NTPCONF}
   fi

   # Only enable NTPD if a "server" line is found
   if [[ $(grep "^server" ${NTPCONF}) ]]
   then
      chroot ${CHROOT} /bin/sh -c "/sbin/chkconfig ntpd on" 
   else
      printf "${NTPCONF} does not exist or does not " > /dev/stderr
      printf "have a \"server\" defined.\n" > /dev/stderr
      printf "NTPD not configured/enabled.\n" > /dev/stderr
   fi
fi

# Ensure that tmp.mount Service is enabled
chroot ${CHROOT} /bin/systemctl unmask tmp.mount 
chroot ${CHROOT} /bin/systemctl enable tmp.mount 

# Ensure that SELinux policy files are installed
chroot ${CHROOT} /bin/sh -c "(rpm -q --scripts selinux-policy-targeted | \
   sed -e '1,/^postinstall scriptlet/d' | \
   sed -e '1i #!/bin/sh') > /tmp/selinuxconfig.sh ; \
   sh /tmp/selinuxconfig.sh 1"

