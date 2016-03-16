#!/bin/sh
#
# Script to automate and standardize installation of AWScli tools
############################################################
SCRIPTROOT="$(dirname ${0})"
CHROOT="${CHROOT:-/mnt/ec2-root}"
BUNDLE="awscli-bundle.zip"
ZIPSRC="${1:-https://s3.amazonaws.com/aws-cli}"
AWSZIP="/tmp/${BUNDLE}"

# Bail if bogus location for ZIP
printf "Fetching ${BUNDLE} from ${ZIPSRC}..."
(cd /tmp ; curl -sL "${ZIPSRC}/${BUNDLE}" -o ${BUNDLE})
echo

if [[ ! -f "${AWSZIP}" ]]
then
   echo "Did not find software at ${AWSZIP}. Aborting..." > /dev/stderr
   exit 1
elif [[ $(file -b "${AWSZIP}" | cut -d " " -f 1) != "Zip" ]]
then
   echo "${AWSZIP} is not a ZIP-archive. Aborting..." > /dev/stderr
   exit 1
else
   echo "Downloaded ${ZIPSRC}/${BUNDLE} to ${AWSZIP}."
fi

# Unzip the AWScli bundle into /tmp
(cd /tmp ; unzip ${AWSZIP})

# Copy the de-archived zip to ${CHROOT}
cp -r /tmp/awscli-bundle ${CHROOT}/root

# Install AWScli bundle into ${CHROOT}
chroot ${CHROOT} /root/awscli-bundle/install -i /opt/aws -b /usr/bin/aws

# Verify AWScli functionality within ${CHROOT}
chroot ${CHROOT} /usr/bin/aws --version

# Cleanup
rm -rf ${CHROOT}/root/awscli-bundle

# Install other AWS utilities to CHROOT
BLDREG=$(curl -s \
         http://169.254.169.254/latest/dynamic/instance-identity/document | \
         awk -F":" '/region/{print $2}' | sed -e 's/",.*$//' -e 's/^.*"//')

# If RedHat, stage a temp. RH yum-config
if [[ $(rpm -qa | grep -q rhui)$? -eq 0 ]]
then
   sed 's/\.REGION\./.'${BLDREG}'./' /etc/yum.repos.d/redhat-rhui.repo > \
     ${CHROOT}/etc/yum.repos.d/test.repo
fi

yum --installroot=${CHROOT} install -y ${SCRIPTROOT}/AWSpkgs/*.noarch.rpm

# Nuke temp. RH yum-config if it exists
if [ -e ${CHROOT}/etc/yum.repos.d/test.repo ]
then
   rm -f ${CHROOT}/etc/yum.repos.d/test.repo
fi
