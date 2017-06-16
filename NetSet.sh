#!/bin/sh
#
# Script to enable networking in the EL7 AMI:
# * Enable DHCP client for default interface (eth0)
# * Configure basic networking-behavior
# * Configure basic SSHD behavior
#
#################################################################
CHROOT="${CHROOT:-/mnt/ec2-root}"

# Create default if-script
cat <<EOF > "${CHROOT}/etc/sysconfig/network-scripts/ifcfg-eth0"
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="yes"
PEERDNS="yes"
IPV6INIT="no"
PERSISTENT_DHCLIENT="1"
EOF

# Create stub network config scripts
cat <<EOF > "${CHROOT}/etc/sysconfig/network"
NETWORKING="yes"
NETWORKING_IPV6="no"
NOZEROCONF="yes"
HOSTNAME="localhost.localdomain"
EOF

# Make ssh relax about root logins
cat <<EOF >> "${CHROOT}/etc/ssh/sshd_config"
UseDNS no
PermitRootLogin without-password
EOF

chroot "${CHROOT}" systemctl enable network
