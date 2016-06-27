The scripts in this directory should be executed in the order listed.

DiskSetup.sh:		Configure attached EBS into target partitioning-state.
			Honors the flags:
			  -b|--bootlabel:
                             FS-label applied to '/boot' filesystem
                          -d|--disk:
                             dev-path to disk to be partitioned
                          -r|--rootlabel:
                             FS-label to apply to '/' filesystem (no LVM in use)
                          -v|--vgname:
                             LVM2 Volume-Group name for root volumes
			Note: the "-r" and "-v" options are mutually exclusive


MkChrootTree.sh:	Setup/mount chroot'ed volumes/partitions
			Argument 1: dev-path to target disk

MkTabs.sh:		Setup chroot's /etc/fstab file (systemd now owns all
			pseudo-filesystems)
			<no arguments>

ChrootBuild.sh:		Install initial, minimal RPM-set into chroot
			<no arguments>

==========
     Insert local customizations, here. If deploying to a 
     disconnected network (e.g., an isolated VPC) or network 
     using private/customized yum repos, run any repo-setup
     scripts, here.
==========

AWScliSetup.sh:		Install AWS utilities (scripting tools and optimized
			drivers for HVM instances)
			Argument 1 (optional): root-URI path to site's private
			   AWS CLI bundle-installer. Defaults to:
			      https://s3.amazonaws.com/aws-cli
			Argument 2 (optional): path to site's private EPEL
			   repository definition file. Defaults to:
			      https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-7.noarch.rpm

ChrootCfg.sh:		Perform supplementary configuration of components
			within ${CHROOT}
GrubSetup.sh:		Configures GRUB2 to target the root LVM2 volume-group
			and installs requisite bootblock into the MBR.
			Argument 1: device-path containing root volume-group

NetSet.sh:		Configure AMI to use DHCP for IP address management
			<no arguments>

CleanChroot.sh:		Do some file cleanup...
			<no arguments>

PreRelabel.sh:		Do SELinux auto-relabel prior to taking the snapshot.
			Obviates need for boot-time relabel operation.

UmountChroot.sh:	Dismount and deactivate the chroot EBS
			<no arguments>
