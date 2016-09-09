#!/bin/bash
#
# Install minimal RPM-set into chroot
#
#####################################
PROGNAME=$(basename "$0")
CHROOT="${CHROOT:-/mnt/ec2-root}"
CONFROOT=$(dirname $0)
DISABLEREPOS="*media*,*epel*,C*-*,*-source-*,*-debug-*"

function PrepChroot() {
   local REPOPKGS=($(echo \
                     $(rpm --qf '%{name}\n' -qf /etc/redhat-release) ; \
                     echo $(rpm --qf '%{name}\n' -qf \
                            /etc/yum.repos.d/* 2>&1 | \
                            grep -v "not owned" | sort -u)
                   ))

   # Do this so that install of chkconfig RPM succeeds
   if [[ ! -e ${CHROOT}/etc/init.d ]]
   then
      ln -t ${CHROOT}/etc -s ./rc.d/init.d
   fi
   if [[ ! -e ${CHROOT}/etc/rc.d/init.d ]]
   then
      install -d -m 0755 ${CHROOT}/etc/rc.d/init.d 
   fi

   yumdownloader --destdir=/tmp ${REPOPKGS[@]}
   rpm --root ${CHROOT} --initdb
   rpm --root ${CHROOT} -ivh --nodeps /tmp/*.rpm

   yum --enablerepo=${BONUSREPO} --disablerepo=${DISABLEREPOS} \
      --installroot=${CHROOT} -y reinstall ${REPOPKGS[@]}
   yum --enablerepo=${BONUSREPO} --disablerepo=${DISABLEREPOS} \
      --installroot=${CHROOT} -y install yum-utils

   # if alt-repo defined, disable everything, then install alt-repo
   if [[ ! -z ${REPORPM+xxx} ]]
   then
      for FILE in ${CHROOT}/etc/yum.repos.d/*.repo
      do
         sed -i '{
	    /^\[/{N
	       s/\n/&enabled=0\n/
            }
	    /^enabled=1/d
         }' "${FILE}"
      done
      rpm --root ${CHROOT} -ivh --nodeps "${REPORPM}"
   fi
}


######################
## Main program flow
######################

# See if we'e passed any valid flags
OPTIONBUFR=$(getopt -o r:b: --long repouri:bonusrepos: -n ${PROGNAME} -- "$@")
eval set -- "${OPTIONBUFR}"

while [[ true ]]
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
	       REPORPM=${2}
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

if [[ ! -z ${BONUSREPO+xxx} ]]
then
   ENABREPO=--enablerepo="${BONUSREPO}"
   YUMDO="yum --nogpgcheck --installroot=${CHROOT} ${ENABREPO} install -y"
else
   YUMDO="yum --nogpgcheck --installroot=${CHROOT} install -y"
fi

# Activate repos in the chroot...
TOACTIVATE=($(chroot $CHROOT yum --enablerepo=* \
               --disablerepo="${DISABLEREPOS}" repolist | \
               sed -e '1,/^repo id/d' -e '/^repolist:/d' -e 's/\/.*$//'))
CHROOTREPOS=$(echo "${TOACTIVATE[@]}" | sed -e 's/\s/,/g')


chroot $CHROOT yum-config-manager --enable ${CHROOTREPOS}

# Install main RPM-groups
${YUMDO} "${DISABLEREPOS}" @core -- \
$(rpm --qf '%{name}\n' -qf /etc/yum.repos.d/* 2>&1 | grep -v "not owned" | sort -u) \
    authconfig \
    chrony \
    cloud-init \
    cloud-utils-growpart \
    dracut-config-generic \
    dracut-fips \
    dracut-norescue \
    gdisk \
    grub2 \
    grub2-tools \
    iptables-services \
    iptables-utils \
    kernel \
    kexec-tools \
    lvm2 \
    ntp \
    ntpdate \
    openssh-clients \
    openssh-server \
    rootfiles \
    rsync \
    selinux-policy-targeted \
    sudo \
    tar \
    vim-common \
    wget \
    yum-utils \
    -abrt \
    -abrt-addon-ccpp \
    -abrt-addon-kerneloops \
    -abrt-addon-python \
    -abrt-cli \
    -abrt-libs \
    -aic94xx-firmware \
    -alsa-firmware \
    -alsa-lib \
    -alsa-tools-firmware \
    -biosdevname \
    -gcc-gfortran \
    -iprutils \
    -ivtv-firmware \
    -iwl1000-firmware \
    -iwl100-firmware \
    -iwl105-firmware \
    -iwl135-firmware \
    -iwl2000-firmware \
    -iwl2030-firmware \
    -iwl3160-firmware \
    -iwl3945-firmware \
    -iwl4965-firmware \
    -iwl5000-firmware \
    -iwl5150-firmware \
    -iwl6000-firmware \
    -iwl6000g2a-firmware \
    -iwl6000g2b-firmware \
    -iwl6050-firmware \
    -iwl7260-firmware \
    -libertas-sd8686-firmware \
    -libertas-sd8787-firmware \
    -libertas-usb8388-firmware \
    -libvirt-client \
    -libvirt-devel \
    -libvirt-java \
    -libvirt-java-devel \
    -nc \
    -NetworkManager \
    -plymouth \
    -sendmail
