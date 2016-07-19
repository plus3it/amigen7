# Extensions planned for the future:
* Enhancing the EBS-carving routines
  * Accommodate other than 20GiB root EBS
  * Accommodate user-driven partition-sizing (note: no plans are in place to include partitions not prescribed by STIG- or [SCAP-](https://fedorahosted.org/scap-security-guide/)guidance. It is assumed that non SCAP-prescribed partitioning will primarily be for hosting application-data - and that such data will be segregated from OS data via encapsulation in other than the root LVM2 volume-group)
* Add the ability to register the configured chroot-disk as an AMI without having to use the web console. Because the registration-methods for license-included RHEL differs significantly - and is much more complex to accommodate - this feature for RHEL will significantly lag implementation for distros not requiring licensing
