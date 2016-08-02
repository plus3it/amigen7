The AMIgen7 scripts require several packages to be present in order to work correctly. Use the following UserData when launching an EL7 AMI to perform a bootstrap-build from:

    #cloud-config
    package_upgrade: true
    packages:
      - coreutils
      - device-mapper
      - device-mapper-event
      - device-mapper-event-libs
      - device-mapper-libs
      - device-mapper-persistent-data
      - e2fsprogs
      - gawk
      - git
      - grep
      - grub
      - grub2
      - grub2-tools
      - grubby
      - libudev
      - lvm2
      - lvm2-libs
      - openssl
      - parted
      - sed
      - sysvinit-tools
      - unzip
      - util-linux-ng
      - yum-utils
      - zip
