- - - 
**NOTE: this project is not ready for use. All current content is borrowed from the [ferricoxide/AMIgen6](https://github.com/ferricoxide/AMIgen6) project**
- - - 
The scripts in this project are designed to ease the creation of LVM-enabled Enterprise Linux AMIs for use in AWS envrionments. It has been successfully tested with CentOS 7.x, Scientific Linux 7.x and Red Hat Enterprise Linux 7.x. It should work with other EL7-derived operating systems.

Please see the RHEL7 subdirectory for directions/scripts specifically required to leverage this solution for creating license-included RHEL7 AMIs.

If attempting to port for other EL7 derivatives that use publicly-accessible repositories create a yum-build.conf file to point to the distro-specific public repositories. Use the yum-build_CentOS.conf and yum-build_SciLin.conf files as references for creating a yum-build.conf file appropriate to your distro of choice.

Please read through all of the READMEs before using. Most of the errors you're likely to encounter can be avoided by doing so. Yes, I'm aware there's some gaps, but, it's not yet been a high-priority to fix them (particularly when they can be avoided by using the READMEs). If there are any really egregious gaps or gaps that I've not covered in the READMEs, please open an issue.

Extensions planned for the future:
* Add the ability to automate the creation/attachment of the CHROOT EBS via the [AWS CLI-tools](http://docs.aws.amazon.com/cli/latest/userguide/installing.html#install-bundle-other-os).
* Enhancing the EBS-carving routines
  * Accommodate other than 20GiB root EBS
  * Accommodate user-driven partition-sizing (note: no plans are in place to include partitions not prescribed by [SCAP guidance](https://fedorahosted.org/scap-security-guide/). It is assumed that non SCAP-prescribed partitioning will primarily be for hosting application-data - and that such data will be segregated from OS data via encapsulation in other than the root LVM2 volume-group)
* Add the ability to register the configured chroot-disk as an AMI without having to use the web console. Because the registration-methods for license-included RHEL differs significantly - and is much more complex to accommodate - this feature for RHEL will significantly lag implementation for distros not requiring licensing
