#!/bin/bash
# shellcheck disable=SC2005,SC2001,SC2181,SC2207,SC2236
#
# Install minimal RPM-set into chroot
#
#####################################
PROGNAME=$(basename "$0")
CHROOT="${AMIGENCHROOT:-/mnt/ec2-root}"

case $( rpm -qf /etc/os-release --qf '%{name}' ) in
   centos-release)
      OSREPOS=(
         os
         base
         updates
         extras
      )
      ;;
   oraclelinux-release)
      OSREPOS=(
         ol7_latest
         ol7_UEKR5
      )
      ;;
   redhat-release-server)
      OSREPOS=(
         rhui-REGION-client-config-server-7
         rhui-REGION-rhel-server-releases
         rhui-REGION-rhel-server-rh-common
         rhui-REGION-rhel-server-optional
         rhui-REGION-rhel-server-extras
      )
      ;;
   *)
      echo "Unknown OS. Aborting" >&2
      exit 1
      ;;
esac

DEFAULTREPOS=$(printf ",%s" "${OSREPOS[@]}" | sed 's/^,//')
EXPANDED=()
FIPSDISABLE="${FIPSDISABLE:-UNDEF}"
MANIFESTFILE=""
PKGLIST=()
RPMGRP="core"
YCM="/bin/yum-config-manager"

export EXPANDED PKGLIST

# Print out a basic usage message
function UsageMsg {
   (
## r:b:e:hm:
## repouri:,bonusrepos:,extras:,help,pkg-manifest:
      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf "\t-b <REPOS_TO_ACTIVATE>\n"
      printf "\t-e <EXTRA_RPMS>\n"
      printf "\t-g <RPM_GROUP_NAME>\n"
      printf "\t-h print this message\n"
      printf "\t-m <PKG_MANIFEST_FILE>\n"
      printf "\t-r <REPO_RPM_URIs>\n"
      echo "  GNU long options:"
      printf "\t--bonusrepos <REPOS_TO_ACTIVATE>\n"
      printf "\t--extras <EXTRA_RPMS>\n"
      printf "\t--help print this message\n"
      printf "\t--pkg-manifest <PKG_MANIFEST_FILE>\n"
      printf "\t--repouri <REPO_RPM_URIs>\n"
      printf "\t--rpm-group <RPM_GROUP_NAME>\n"
   )
   exit 1
}

function PrepChroot() {

   if [ -f "/etc/oracle-release" ]
   then
      # we cannot install oraclelinux-release-el7.rpm due to script dependencies to other RPMs
      # => the strategy from CentOS/RHEL could not be used here...
      local REPOPKGS="yum-utils"

      # setup some public-yum settings for onPremise installations
      mkdir -p "${CHROOT}/etc/yum/vars"
      touch "${CHROOT}/etc/yum/vars/ociregion"

      mkdir -p "${CHROOT}/etc/yum.repos.d"
      # copy repositoryfiles manually
      cp /etc/yum.repos.d/*ol7.repo "${CHROOT}/etc/yum.repos.d"
   else
      local REPOPKGS=($(echo \
                        "$(rpm --qf '%{name}\n' -qf /etc/redhat-release)" ; \
                        echo "$(rpm --qf '%{name}\n' -qf \
                              /etc/yum.repos.d/* 2>&1 | \
                              grep -v "not owned" | sort -u)" ; \
                        echo yum-utils
                     ))
   fi
   # Enable DNS resolution in the chroot
   if [[ ! -e ${CHROOT}/etc/resolv.conf ]]
   then
      install -m 0644 /etc/resolv.conf "${CHROOT}/etc"
   fi

   # Do this so that install of chkconfig RPM succeeds
   if [[ ! -e ${CHROOT}/etc/init.d ]]
   then
      ln -t "${CHROOT}/etc" -s ./rc.d/init.d
   fi
   if [[ ! -e ${CHROOT}/etc/rc.d/init.d ]]
   then
      install -d -m 0755 "${CHROOT}/etc/rc.d/init.d"
   fi

   # cleanup RPMs from previous runs
   rm -f /tmp/*.rpm
   yumdownloader --destdir=/tmp "${REPOPKGS[@]}"
   rpm --root "${CHROOT}" --initdb
   rpm --root "${CHROOT}" -ivh --nodeps /tmp/*.rpm

   # When we don't specify repos, default to a sensible value-list
   if [[ -z ${BONUSREPO} ]]
   then
      BONUSREPO=${DEFAULTREPOS}
   fi

   yum --disablerepo="*" --enablerepo="${BONUSREPO}" \
      --installroot="${CHROOT}" -y reinstall "${REPOPKGS[@]}"
   yum --disablerepo="*" --enablerepo="${BONUSREPO}" \
      --installroot="${CHROOT}" -y install yum-utils

   # if alt-repo defined, disable everything, then install alt-repos
   if [[ -n ${REPORPMS[*]} ]]
   then
      for RPM in "${REPORPMS[@]}"
      do
         { STDERR=$(rpm --root "${CHROOT}" -ivh --nodeps "${RPM}" 2>&1 1>&$out); } {out}>&1 || echo "$STDERR" | grep "is already installed"
      done
   fi
}


######################
## Main program flow
######################

# See if we'e passed any valid flags
OPTIONBUFR=$(getopt -o r:b:e:g:hm: --long repouri:,bonusrepos:,extras:,help,pkg-manifest:,rpm-group -n "${PROGNAME}" -- "$@")
eval set -- "${OPTIONBUFR}"

while true
do
   case "$1" in
      -r|--repouri)
         case "$2" in
	    "")
	       echo "Error: option required but not specified" > /dev/stderr
	       shift 2;
	       exit 1
	       ;;
	    *)
	       IFS=, read -ra REPORPMS <<< "$2"
	       shift 2;
	       ;;
	 esac
	 ;;
      -b|--bonusrepos)
         case "$2" in
	    "")
	       echo "Error: option required but not specified" > /dev/stderr
	       shift 2;
	       exit 1
	       ;;
	    *)
	       BONUSREPO=${2}
	       shift 2;
	       ;;
	 esac
	 ;;
      -e|--extras)
         case "$2" in
	    "")
	       echo "Error: option required but not specified" > /dev/stderr
	       shift 2;
	       exit 1
	       ;;
	    *)
	       IFS=, read -ra EXTRARPMS <<< "$2"
	       shift 2;
	       ;;
	 esac
	 ;;
      -h|--help)
         UsageMsg
         ;;
      -m|--pkg-manifest)
         case "$2" in
	    "")
	       echo "Error: option required but not specified" > /dev/stderr
	       shift 2;
	       exit 1
	       ;;
	    *)
	       MANIFESTFILE="${2}"
	       shift 2;
	       ;;
	 esac
	 ;;
      -g|--rpm-group)
         case "$2" in
	    "")
	       echo "Error: option required but not specified" > /dev/stderr
	       shift 2;
	       exit 1
	       ;;
	    *)
	       RPMGRP="${2}"
	       shift 2;
	       ;;
	 esac
         ;;
      --)
         shift
	 break
	 ;;
      *)
         echo "Internal error!" > /dev/stderr
	 exit 1
	 ;;
   esac
done

# Stage useable repo-defs into $CHROOT/etc/yum.repos.d
PrepChroot

if [[ -n "$BONUSREPO" ]]
then
   ENABREPO=--enablerepo=${BONUSREPO}
   # shellcheck disable=SC2125
   YUMDO="yum --nogpgcheck --installroot=${CHROOT} --disablerepo="*" ${ENABREPO} install -y"
else
   YUMDO="yum --nogpgcheck --installroot=${CHROOT} install -y"
fi

# Activate repos in the chroot...
chroot "$CHROOT" "${YCM}" --disable "*"
chroot "$CHROOT" "${YCM}" --enable "${BONUSREPO}"

# Whether to include FIPS kernel modules...
case "${FIPSDISABLE}" in
   true|TRUE|1|on)
      FIPSRPM=''
      ;;
   UNDEF|''|false|FALSE|0)
      FIPSRPM='dracut-fips'
      ;;
esac

# Setup the "include" package list

# Use manifest file if found and non-empty
if [[ -n ${MANIFESTFILE} ]] && [[ -s ${MANIFESTFILE} ]]
then
   echo "Selecting packages from ${MANIFESTFILE}..."
   INCLUDE_PKGS=($( < "${MANIFESTFILE}" ))
# Pull manifest data from yum repository group metadata
else
   echo "Installing default package (@${RPMGRP}) from repo group-list..."

   # Simple case
   if [[ ${RPMGRP} == core ]]
   then
      # shellcheck disable=SC2086
      INCLUDE_PKGS=( $(yum groupinfo ${RPMGRP} 2>&1 | \
         sed -n '/Mandatory/,/Optional Packages:/p' | \
         sed -e '/^ [A-Z]/d' -e 's/^[[:space:]]*[-=+[:space:]]//' ) )
   # Deal with super-groups
   else
      GROUPINFO="$( yum -q groupinfo "${RPMGRP}" 2> /dev/null )"

      if [[ -n ${GROUPINFO} ]]
      then
         SUBGROUPS=( $( echo "${GROUPINFO}" | \
            sed -n -e '/Mandatory Groups:/,/Optional Groups:/p' | \
            sed -e '/:$/d' -e 's/^\s*+//' ) )
      else
         printf "Group '%s' is not valid\n" "${RPMGRP}"
         exit 1
      fi


      # Expand sub-groups to lists of RPMs
      if [[ -n ${SUBGROUPS[*]} ]]
      then
         printf "Found following sub-groups in '%s': %s\n" "${RPMGRP}" "${SUBGROUPS[*]}"

         # Work around "no groups availble on fresh installs"
         # shortcoming (per BZ #1073484)
         yum groups mark convert

         for PKGGRP in ${SUBGROUPS[*]}
         do
            IFS=$'\n' read -r -d '' -a EXPANDED < <( yum groupinfo "${PKGGRP}" | \
               sed -n -e '/Description:/,/Optional Packages:/p' | \
               sed -e '/[a-z]*:/d' -e 's/^\s*[+=-]*//' && printf '\0' )

            # Expand PKGLIST array as appropriate
            if [[ ${#PKGLIST[@]} -gt 0 ]] && [[ ${#EXPANDED[@]} -gt 0 ]]
            then
               PKGLIST=( "${PKGLIST[@]}" "${EXPANDED[@]}" )
            elif [[ ${#PKGLIST[@]} -eq 0 ]] && [[ ${#EXPANDED[@]} -gt 0 ]]
            then
               PKGLIST=( "${EXPANDED[@]}" )
            fi
            EXPANDED=()
         done
      fi
      INCLUDE_PKGS=( "${PKGLIST[@]}" )
   fi
fi

# Detect if target-reposity has requisite metadata
if [[ ${INCLUDE_PKGS[*]} == "" ]]
then
   echo "Unable to fetch group metadata from target yum-repository. ABORTING."
   exit 1
else
   echo "Fetched group metadata from target yum-repository."
fi

INCLUDE_PKGS+=($(rpm --qf '%{name}\n' -qf /etc/yum.repos.d/* 2>&1 | grep -v "not owned" | sort -u || true))
INCLUDE_PKGS+=(
    authconfig
    chrony
    cloud-init
    cloud-utils-growpart
    dracut-config-generic
    gdisk
    grub2
    grub2-tools
    iptables-services
    iptables-utils
    kernel
    kexec-tools
    lvm2
    ntp
    ntpdate
    openssh-clients
    openssh-server
    rdma-core
    rootfiles
    rsync
    selinux-policy-targeted
    sudo
    tar
    vim-common
    wget
    yum-utils
)
if [[ -n "$FIPSRPM" ]];
then
    INCLUDE_PKGS+=("$FIPSRPM")
fi

# Setup the "exclude" package list
EXCLUDE_PKGS=(
    -abrt
    -abrt-addon-ccpp
    -abrt-addon-kerneloops
    -abrt-addon-python
    -abrt-cli
    -abrt-libs
    -aic94xx-firmware
    -alsa-firmware
    -alsa-lib
    -alsa-tools-firmware
    -bfa-firmware
    -biosdevname
    -gcc-gfortran
    -iprutils
    -ivtv-firmware
    -iwl1000-firmware
    -iwl100-firmware
    -iwl105-firmware
    -iwl135-firmware
    -iwl2000-firmware
    -iwl2030-firmware
    -iwl3160-firmware
    -iwl3945-firmware
    -iwl4965-firmware
    -iwl5000-firmware
    -iwl5150-firmware
    -iwl6000-firmware
    -iwl6000g2a-firmware
    -iwl6000g2b-firmware
    -iwl6050-firmware
    -iwl7260-firmware
    -iwl7265-firmware
    -libertas-sd8686-firmware
    -libertas-sd8787-firmware
    -libertas-usb8388-firmware
    -libvirt-client
    -libvirt-devel
    -libvirt-java
    -libvirt-java-devel
    -nc
    -NetworkManager
    -plymouth
    -ql2100-firmware
    -ql2200-firmware
    -ql23xx-firmware
    -rdma
    -sendmail
)

# Strip excluded pkgs from the include list
for PKG in "${EXCLUDE_PKGS[@]}"
do
    mapfile -t INCLUDE_PKGS < <(printf '%s\n' "${INCLUDE_PKGS[@]}" | grep -xv "^${PKG/-/}$")
done

# Install main RPM-groups
$YUMDO -- "${INCLUDE_PKGS[@]}" "${EXCLUDE_PKGS[@]}"

# Validate all included packages were installed
rpm --root "${CHROOT}" -q "${INCLUDE_PKGS[@]}"

# Install additionally-requested RPMs
if [[ -n ${EXTRARPMS[*]} ]]
then
   printf "##########\n## Installing requested RPMs/groups\n##########\n"
   for RPM in "${EXTRARPMS[@]}"
   do
      { STDERR=$(${YUMDO} "$RPM" 2>&1 1>&$out); } {out}>&1 || echo "$STDERR" | grep "Error: Nothing to do"
   done

else
   echo "No 'extra' RPMs requested"
fi
