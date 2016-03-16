#!/bin/sh
#
# Script to set up the chroot'ed /etc/fstab
#
#################################################################
CHROOT="${CHROOT:-/mnt/ec2-root}"
CHROOTDEV=${1:-UNDEF}
FSTAB="${CHROOT}/etc/fstab"
SCRIPTDIR="$(dirname $0)"
YUMCONF="${SCRIPTDIR}/yum-chroot.conf"

# Verify that YUM0 is set
if [[ -z "${YUM0+xxx}" ]]
then
   echo "The 'YUM0' env is not set. Aborting..." > /dev/stderr
   exit 1
fi

# Create yum-chroot.conf as necessary
if [[ ! -f "${YUMCONF}" ]]
then
   if [[ $(rpm --quiet -q centos-release)$? -eq 0 ]]
   then
      sed '{
         s/^\[/&chroot-/
         s/\$releasever/'${YUM0}'/
         s/\$basearch/x86_64/g
         s/^#base/base/
      }' /etc/yum.repos.d/CentOS-Base.repo > yum-chroot.conf
   fi
fi

yum --disablerepo="*" --enablerepo="chroot-*" -c yum-chroot.conf \
    --installroot=$CHROOT install @core -- \
    authconfig \
    cloud-init \
    grub2 \
    kernel \
    lvm2 \
    man \
    ntp \
    ntpdate \
    openssh-clients \
    selinux-policy \
    wget \
    yum-cron \
    yum-utils \
    -abrt \
    -abrt-addon-ccpp \
    -abrt-addon-kerneloops \
    -abrt-addon-python \
    -abrt-cli \
    -abrt-libs \
    -gcc-gfortran \
    -libvirt-client \
    -libvirt-devel \
    -libvirt-java \
    -libvirt-java-devel \
    -nc \
    -sendmail
