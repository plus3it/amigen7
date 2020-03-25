#!/bin/bash
# shellcheck disable=SC2015
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
SCRIPTROOT="$( dirname "${0}" )"
CHROOT="${CHROOT:-/mnt/ec2-root}"
BUNDLE="awscli-bundle.zip"
ZIPSRC="${1:-https://s3.amazonaws.com/aws-cli/awscli-bundle.zip}"
EPELRELEASE="${2:-https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm}"
PRIVREPOS="${3}"
AWSZIP="/tmp/${BUNDLE}"
SYSTEMDSVCS=(
      autotune.service
      amazon-ssm-agent.service
      hibinit-agent.service
      ec2-instance-connect.service
   )

check_AMZNRPMS()
{
   # Make sure the AMZN.Linux packages are present
   mapfile -t AMZNRPMS < <( stat -c '%n' "${SCRIPTROOT}"/AWSpkgs/*.el7.*.rpm )
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
}

enable_rhel_optional()
{
   # Enable the RHEL "optional" repo where appropriate
   OPTIONREPO=$(yum repolist all | grep rhel-server-optional || true)
   if [[ -n ${OPTIONREPO} ]]
   then
      chroot "${CHROOT}" yum-config-manager --enable "${OPTIONREPO/\/*/}"
   fi

   # Enabled requested repos in chroot() environment
   if [[ -n ${PRIVREPOS+xxx} ]]
   then
      chroot "${CHROOT}" yum-config-manager --enable "${PRIVREPOS}"
   fi
}

install_awscli()
{
   # Bail if bogus location for ZIP
   printf "Fetching %s from ${ZIPSRC}..." "${BUNDLE}"
   (cd /tmp && curl -sL "${ZIPSRC}" -o "${BUNDLE}")
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
      echo "Downloaded ${ZIPSRC} to ${AWSZIP}."
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
}

enable_services()
{
   # Need to force systemd services to be enabled in resultant AMI
   for SVC in "${SYSTEMDSVCS[@]}"
   do
      printf "Attempting to enable %s in %s... " "${SVC}" "${CHROOT}"
      chroot "${CHROOT}" /usr/bin/systemctl enable "${SVC}" && echo "Success" || \
        ( echo "FAILED" ; exit 1 )
   done
}

get_awstools_filenames()
{
   if [[ -z ${AWSTOOLSRPM:-} ]]
   then
      ls "${SCRIPTROOT}"/AWSpkgs/*.el7.*.rpm
   else
      rpmfiles=""
      for rpmfile in ${AWSTOOLSRPM}
      do
         rpmfiles="${rpmfiles} "$(ls "${SCRIPTROOT}/AWSpkgs/${rpmfile}"*.el7.*.rpm)
      done
      echo "${rpmfiles}"
   fi
}

install_awstools()
{
   # Depending on RPMs dependencies, this may fail if a repo is
   # missing (e.g. EPEL). Will also fail if no RPMs are present
   # in the search directory.
   # use yum info .. to check and show details for installed RPMs.
   rpmfiles=$(get_awstools_filenames)
   if [[ -z ${rpmfiles} ]]
   then
      echo "No Installation of addional Amazon RPMs"
   else
      epelpkgname=$( rpm -qp --qf "%{NAME}\n" "${EPELRELEASE}" )
      yum info "$epelpkgname" >/dev/null 2>&1 || yum install -y "${EPELRELEASE}" 
      ( yum --installroot="${CHROOT}" info "$epelpkgname" >/dev/null 2>&1 ) || \
        yum --installroot="${CHROOT}" install -y "${EPELRELEASE}" 
      # shellcheck disable=2086
      yum --installroot="${CHROOT}" install -e 0 -y ${rpmfiles} || exit $?

   enable_services
   fi
}

check_AMZNRPMS
enable_rhel_optional
install_awscli
install_awstools
