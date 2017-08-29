#!/bin/sh
# shellcheck disable=SC2086,SC2046,SC2010
#
# Attempt to auto-populate the AWSpkgs directory
#
#################################################################
SCRIPTROOT="$(dirname ${0})"
CHROOT="${CHROOT:-/mnt/ec2-root}"
PROJECT="Lx-GetAMI-Utils"
AMZNLXGIT="${1:-https://github.com/ferricoxide/${PROJECT}.git}"
ELVERSION="el$(rpm --qf '%{version}' -q $(rpm -qf /etc/redhat-release))"

# Fetch Amzn.Linux RPMs if necessary
if [[ -d ${SCRIPTROOT}/../${PROJECT} ]]
then
   echo "Amzn.Linux project-dir exits"
else
   echo "Attempting to fetch project..."
   ( cd "${SCRIPTROOT}/".. || exit 1
     git clone "${AMZNLXGIT}" )
   if [[ ! -d ${SCRIPTROOT}/../${PROJECT} ]]
   then
      echo "Failed to download ${AMZNLXGIT}. Aborting..." > /dev/stderr
      exit 1
   fi
fi

# Grab platform RPMs
case ${ELVERSION} in
   el6)
        RPMLIST=($(ls -1 "${SCRIPTROOT}"/../"${PROJECT}"/*.rpm | grep -v el7))
        ;;
   el7)
        RPMLIST=($(ls -1 "${SCRIPTROOT}"/../"${PROJECT}"/*.rpm | grep -v el6))
        ;;
   *)   echo "Platform not supported. Aborting..." > /dev/stederr
        exit 1
        ;;
esac

LOOP=0
while [[ ${LOOP} -lt ${#RPMLIST[@]} ]]
do
   echo "Copying ${RPMLIST[${LOOP}]} to AWSpkgs"
   ln "${RPMLIST[${LOOP}]}" AWSpkgs
   # shellcheck disable=SC2004
   LOOP=$(($LOOP + 1))
done
