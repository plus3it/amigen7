#!/bin/bash
#
# Do some file cleanup...
#
#########################
CHROOT=${CHROOT:-/mnt/ec2-root}
CONFROOT=`dirname $0`
CLOUDCFG="$CHROOT/etc/cloud/cloud.cfg"
MAINTUSR="maintuser"

# Disable EPEL repos
chroot ${CHROOT} yum-config-manager --disable "*epel*" > /dev/null

# Get rid of stale RPM data
chroot ${CHROOT} yum clean --enablerepo=* -y packages
chroot ${CHROOT} rm -rf /var/cache/yum
chroot ${CHROOT} rm -rf /var/lib/yum

# Nuke any history data
cat /dev/null > ${CHROOT}/root/.bash_history

# Set TZ to UTC
rm ${CHROOT}/etc/localtime
cp ${CHROOT}/usr/share/zoneinfo/UTC ${CHROOT}/etc/localtime

# Create maintuser
CLINITUSR=$(grep -E "name: (maintuser|centos|ec2-user|cloud-user)" \
            ${CLOUDCFG} | awk '{print $2}')

if [ "${CLINITUSR}" = "" ]
then
   echo "Cannot reset value of cloud-init default-user" > /dev/stderr
else
   echo "Setting default cloud-init user to ${MAINTUSR}"
sed -i '/^system_info/,/^  ssh_svcname/d' ${CLOUDCFG}
sed -i '/syntax=yaml/i\
system_info:\
  default_user:\
    name: maintuser\
    lock_passwd: true\
    gecos: Local Maintenance User\
    groups: [wheel, adm]\
    sudo: ["ALL=(root) NOPASSWD:ALL"]\
    shell: /bin/bash\
  distro: rhel\
  paths:\
    cloud_dir: /var/lib/cloud\
    templates_dir: /etc/cloud/templates\
  ssh_svcname: sshd\
' ${CLOUDCFG}
fi

