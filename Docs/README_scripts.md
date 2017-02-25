# Scripts in Tool-set
The following scripts are part of this tool-set. The scripts are listed in the order to be executed. Execution of all scripts is required to successfully create an AMI:

<table border="0">
  <tr>
    <td valign="top">DiskSetup.sh</td>
    <td valign="top">Configure attached EBS into target partitioning-state. Honors the flags:
      <br/>&nbsp;&nbsp;&nbsp;-b&#124;--bootlabel: FS-label applied to '/boot' filesystem
      <br/>&nbsp;&nbsp;&nbsp;-d|--disk: dev-path to disk to be partitioned
      <br/>&nbsp;&nbsp;&nbsp;-r|--rootlabel: FS-label to apply to '/' filesystem (no LVM in use)
      <br/>&nbsp;&nbsp;&nbsp;-v|--vgname: LVM2 Volume-Group name for root volumes
      <br/>Note: the "-r" and "-v" options are mutually exclusive
</td>
  </tr>
  <tr>
    <td valign="top">MkChrootTree.sh</td>
    <td valign="top">Setup/mount chroot'ed volumes/partitions
      <br/>&nbsp;&nbsp;&nbsp;Argument 1: dev-path to target disk</td>
  </tr>
  <tr>
    <td valign="top">MkTabs.sh</td>
    <td valign="top">Setup chroot's `/etc/fstab` file
  </tr>
  <tr>
    <td valign="top">ChrootBuild.sh</td>
    <td valign="top">Install initial, minimal RPM-set into chroot</td>
  </tr>
  <tr>
    <td valign="top">AWScliSetup.sh</td>
    <td valign="top">Install AWS utilities (scripting tools and optimized drivers for HVM instances)
      <br/>&nbsp;&nbsp;&nbsp;Argument 1 (optional): root-URI path to site's private AWS CLI bundle-installer. Defaults to: https://s3.amazonaws.com/aws-cli
      <br/>&nbsp;&nbsp;&nbsp;Argument 2 (optional): path to site's private EPEL repository definition file. Defaults to: https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-7.noarch.rpm</td>
  </tr>
  <tr>
    <td colspan="2">Insert local customizations, here. If deploying to a disconnected network (e.g., an isolated VPC) or network using private/customized yum repos, run any repo-setup scripts, here.</td>
  </tr>
  <tr>
    <td valign="top">ChrootCfg.sh</td>
    <td valign="top">Perform supplementary configuration of components within ${CHROOT}</td>
  </tr>
  <tr>
    <td valign="top">GrubSetup.sh
    <td valign="top">Configures GRUB2 to target the root LVM2 volume-group and installs requisite bootblock into the MBR.
      <br/>&nbsp;&nbsp;&nbsp;Argument 1: device-path containing root volume-group</td>
  </tr>
  <tr>
    <td valign="top">NetSet.sh
    <td valign="top">Configure AMI to use DHCP for IP address management
  </tr>
  <tr>
    <td valign="top">CleanChroot.sh</td>
    <td valign="top">Do some file cleanup...</td>
  </tr>
  <tr>
    <td valign="top">PreRelabel.sh</td>
    <td valign="top">Do SELinux auto-relabel prior to taking the snapshot. Obviates need for boot-time relabel operation.</td>
  </tr>
  <tr>
    <td valign="top">Umount.sh</td>
    <td valign="top">Dismount and deactivate the chroot EBS</td>
  </tr>
</table>
