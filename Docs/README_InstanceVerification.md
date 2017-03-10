# Verification 

_Note_: This document describes steps for manually validating AMIs produced with AMIgen. Automated procuedures - supplemented with CloudFormation templates and other AWS components - are described in the [Automated Validation document](README_automated_validation.md).

After creating an AMI, it is recommended to launch an instance from the AMI and perform some configuration-verification tasks before publishing the AMI. The AMIgen-created AMIs are notable for supporting:
- Use of LVM for managing root (OS) filesystems (to meet STIG and related security guidelines' requirements).
- Enablement of FIPS 140-2 security mode for the whole OS from intial-boot onward (to meet STIG and related security guidelines' requirements).
- Enablement of SELinux in "Enforcing" security mode from intial-boot onward (to meet STIG and related security guidelines' requirements).
- Enablement of auditing subsystem from intial-boot onward (to meet STIG and related security guidelines' requirements).
- Dynamic resizing of root EBS: allows increasing from 20GiB default, only (e.g., to support remote graphical Linux desktop deployments)
- Supporting 10Gbps mode in m4-generation instance-types (inclusive of C3, C4, D2, I2, R3 and newer instance-types).
- Inclusion of cloud-init for boot-time automated provisioning tasks
- Inclusion of AWS utilities (the AWS CLI, the CloudFormation bootstrapper, etc.)
- Binding to RPM update repositories to support lifecycle patching/sustainment activities (RHEL AMIs link to RHUI; CentOS binds to the CentOS.Org mirros; either may be configured to use private repos as needed).
It is recommended to verify that all of these features are working as expected in instances launched from newly-generated AMIs. 

## Verification-Instance Setup
To set up a in instance with an adequate test-configuration, launch an m4.large instance (t2 instance types can be used, but it will not be possible to verify proper 10Gbps support) with the root EBS increased by 10GiB and UserData defined similar to the following:

~~~
#cloud-config
users:
  - default
  - name: <DESIRED_LOGIN_USERID_1>
    ssh-authorized-keys:
      - <OPEN_SSH_FORMATTED_KEYSTRING>
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: wheel
    lock-passwd: True
    selinux-user: unconfined_u
  - name: <DESIRED_LOGIN_USERID_2>
    ssh-authorized-keys:
      - <OPEN_SSH_FORMATTED_KEYSTRING>
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: wheel
    lock-passwd: True
    selinux-user: unconfined_u
write_files:
  - content: |-
      pvresize /dev/xvda2
      lvresize -r -L +4G VolGroup00/rootVol
      lvresize -r -L +2G VolGroup00/varVol
      sed -i '/diskgrow.sh/d' /etc/rc.d/rc.local
      chmod 644 /etc/rc.d/rc.local
      rm $0
    path: /etc/rc.d/diskgrow.sh
    permissions: '0755'
packages:
  - git
runcmd:
  - parted -s /dev/xvda rm 2 mkpart primary ext4 500m 100%
  - partprobe
  - chmod 755 /etc/rc.d/rc.local
  - echo "/etc/rc.d/diskgrow.sh" >> /etc/rc.d/rc.local
  - init 6
~~~

## UserData Explanation
### `users` Section:
As prototyped, this section causes three users to be created within the instance: the default user and two custom users. The directives:
- `name`: Sets the logical name of the custom user
- `ssh-authorized-keys`: Installs the public key into the custom user's `${HOME}/.ssh/authorized_keys` file (allows passwordless, key-based SSH logins to the custom user's account using the private key associated with the installed public key.
- `groups`: Adds the custom user to the specified group
- `lock-passwd`: Locks the password of the custom user. This disables the ability to login via password - preventing brute-force attacks.
- `selinux-user`: Sets the custom user's target SELinux role.
- `sudo`: Sets the custom user's rights within the `sudo` subsystem. Because the initial users are being configured with locked passwords, it is necessary to configure sudo to allow the defined users to escallate privileges without supplying a password.

### `write_files` Section:
As prototyped, this section creates a "run-once" file that takes care of some basic storage-setup related tasks.
- `content`: Declares that the multi-line block following the declaration is one, contiguous chunk of text to read into the file created.
- `path`: Delcares the name of the file to create.
- `permissions`: Declares the permissions to be assigned to the file.

File ownership will default to `root:root`.

The `/etc/rc.d/diskgrow.sh` script file, when run, will:
- Force the OS to scan the LVM2 physical volume, `/dev/xvda2`, for geometry changes.
- Increase the size of the rootVol LVM2 volume by 4GiB (and the filesystem hosted on the volume, "`/`")
- Increase the size of the varVol LVM2 volume by 2GiB (and the filesystem hosted on the volume, "`/var`")
- Remove reference to the `/etc/rc.d/diskgrow.sh` script file from the `/etc/rc.d/rc.local` file.
- Revert the permissions on `/etc/rc.d/diskgrow.sh` to mode `644`
- Erase the `/etc/rc.d/diskgrow.sh` script file

### `packages` Section:
As prototyped, this section will install the `git` RPM (and any dependencies). This section may be omitted or supplemented as needs dictate. The inclusion of the `git` RPM is provided in case the AMI-tester needs to use git to install any further tools.

### (Omitted) `package_upgrade` Section:
If present, this will cause the instance to do a `yum upgrade -y` type of action at first boot. It is omitted, here, becuse it is assumed that a brand new AMI will already be fully up-to-date at first launch.

### `runcmd` Section:
As prototyped this section will:
- Use the `parted` utility to resize (via a delete and recreation method) the partition conatining the LVM2 volume-group that, in turn, contains the root filesystems.
- Use `partprobe` to request the kernel to reread its partition table.
- Make the `/etc/rc.d/rc.local` executable so that it will be run at next boot.
- Append the `/etc/rc.d/diskgrow.sh` command to the end of the `/etc/rc.d/rc.local` script so that it will be executed at next boot.
- Reboots the instance.

The contents of this section will be saved to the file `/var/lib/cloud/instances/<INSTANCE_ID>/scripts/runcmd`. Because this file can contain sensitive data, cloud-init protects its contents from view by unprivileged user accounts.

## Verification

After the test instance completes its boot-sequence, login to the intance. You can use the AMI default user or any custom users specfied in the UserData section. Once logged in:

1. Escalate privileges to root
1. Use the `ethtool` command to verify that the default network interface is running at `10000Mb/s`(or `10000baseT/Full`)
1. Use the `df` command to verify that the requested changes to the default filesystem and volumes have been made.
1. Use the `lsblk` command to map out the storage configuration.
1. Use the `vgdisplay -s` command to verify that the added storage shows up in the root LVM2 volume-group.
1. Check the contents of the `/home` directory to ensure that the requested user accounts were all created
1. Use `yum repolist` - or other equivalent yum invocation - to verify that the instance is able to talk to its RPM sources.
1. Use `sysctl crypto.fips_enabled` to verify that the instance is actually running in FIPS mode.
1. Use the `getenforce` command to verify that the instance is running in "`Enforcing`" mode.

![instancecheck](https://cloud.githubusercontent.com/assets/7087031/21658997/c4ffa102-d296-11e6-800a-660f0cd02d1e.png)
