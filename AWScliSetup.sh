#!/bin/sh
# shellcheck disable=SC2086
#
# Script to automate and standardize installation of AWScli tools
#
# This script assumes standard AWS-hosted location for the
# CLI ZIP-file. It may be overridden by passing a URI as
# the first argument to the script.
#
# For the second argument, provide the url to the epel-release
# package, or it will default to one publicly available.
#
############################################################
SCRIPTROOT="$(dirname ${0})"
CHROOT="${CHROOT:-/mnt/ec2-root}"
BUNDLE="awscli-bundle.zip"
ZIPSRC="${1:-https://s3.amazonaws.com/aws-cli}"
EPELRELEASE="${2:-https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm}"
PRIVREPOS="${3}"
AWSZIP="/tmp/${BUNDLE}"

# Make sure the AMZN.Linux packages are present
AMZNRPMS=($( stat -c '%n' ${SCRIPTROOT}/AWSpkgs/*noarch.rpm))
if [[ ${#AMZNRPMS[@]} -eq 0 ]]
then
   (
    echo "AMZN.Linux packages not found in ${SCRIPTROOT}/AWSpkgs"
    echo "Please download missing RPMs before proceeding."
    echo "Note: GetAmznLx.sh may be used to do this for you."
    echo "Aborting..."
   ) > /dev/stderr
   exit 1
fi

# Enable the RHEL "optional" repo where appropriate
OPTIONREPO=$(yum repolist all | grep rhel-server-optional | sed 's/\/.*$//')
if [[ ${OPTIONREPO} != "" ]]
then
   chroot "${CHROOT}" yum-config-manager --enable "${OPTIONREPO}"
fi

# Enabled requested repos in chroot() environment
if [[ ! -z ${PRIVREPOS+xxx} ]]
then
    chroot "${CHROOT}" yum-config-manager --enable "${PRIVREPOS}"
fi

# Bail if bogus location for ZIP
printf "Fetching %s from ${ZIPSRC}..." "${BUNDLE}"
(cd /tmp && curl -sL "${ZIPSRC}/${BUNDLE}" -o "${BUNDLE}")
echo

if [[ ! -f ${AWSZIP} ]]
then
   echo "Did not find software at ${AWSZIP}. Aborting..." > /dev/stderr
   exit 1
elif [[ $(file -b "${AWSZIP}" | cut -d " " -f 1) != Zip ]]
then
   echo "${AWSZIP} is not a ZIP-archive. Aborting..." > /dev/stderr
   exit 1
else
   echo "Downloaded ${ZIPSRC}/${BUNDLE} to ${AWSZIP}."
fi

# Unzip the AWScli bundle into /tmp
(cd /tmp && unzip -o ${AWSZIP})

# Copy the de-archived zip to ${CHROOT}
cp -r /tmp/awscli-bundle "${CHROOT}/root"

# Install AWScli bundle into ${CHROOT}
chroot "${CHROOT}" /root/awscli-bundle/install -i /opt/aws/cli -b /usr/bin/aws

# Verify AWScli functionality within ${CHROOT}
chroot "${CHROOT}" /usr/bin/aws --version

# Cleanup
rm -rf "${CHROOT}/root/awscli-bundle"

# Depending on RPMs dependencies, this may fail if a repo is
# missing (e.g. EPEL). Will also fail if no RPMs are present
# in the search directory.
yum install -y "${EPELRELEASE}"
yum --installroot="${CHROOT}" install -y "${EPELRELEASE}"
yum --installroot="${CHROOT}" install -y "${SCRIPTROOT}"/AWSpkgs/*.noarch.rpm \
   || exit $?
