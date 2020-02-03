# Disk Customization

As of this document's author-date (2020-01-29), the AMIgen7 scripts now support the _optional_ creation of AMIs with customized storage-layouts and filesystem sizes.

## Usage

The _default behavior_ for AMIgen7 remains creating AMIs with the following storage-layout:

Root EBS of 20GiB size partitioned as:

* 1st partition: 512MiB primary partition mounted at `/boot`
* 2nd partition: 19.5GiB primary partition placed under the control of LVM2:
    * 4GiB filesystem on `rootVol` LVM volume mounted at `/`
    * 2GiB filesystem on `swapVol` LVM volume mounted as swap
    * 1GiB filesystem on `homeVol` LVM volume mounted at `/home`
    * 2GiB filesystem on `varVol` LVM volume mounted at `/var`
    * 2GiB filesystem on `logVol` LVM volume mounted at `/var/log`
    * &cong;8.5GiB filesystem on `auditVol` LVM volume mounted at `/var/log/audit`

This ensures that any downstream projects that rely on &ndash; or even merely "expect" &ndash; the prior layout will continue to function without modification

To change the storage layout<sup>[1](#Footnote1)</sup>, it will be necessary to:

1. Select an appropriately-sized EBS volume to build onto
1. Invoke the `DiskSetup.sh` utility with the `-p` flag with an argument-string that looks similar to:

    `/:rootVol:8,swap:swapVol:4,/opt:optVol:20,/var:varVol:8,/var/log/audit:auditVol:100%FREE`

    The string is a comma-delimited list of colon-delimited tuples where:

    * First Value: path to mount the filesystem to
    * Second Value: name to assign to the LVM2 volume hosting the filesystem
    * Third Value: size (in GiB) of the LVM2 volume and associated filesystem to create

    Any valid group of tuples that fit within the size of the EBS selected in the firt step should work. To avoid wasting disk space, it is recommended that one tuple substitutes the value `FREE` or `100%FREE` for the numerical value<sup>[2](#Footnote2),[3](#Footnote3)</sup>.
    
1. Invoke the `MkChrootTree.sh` utility with third argument-string identical to the one passed to the `DiskSetup.sh` utility
1. Invoke the remaining utilities as normal for the relevant deployment-context 

## Notes:

<a name="Footnote1">1</a>: If one wishes to main compliant with the STIGs' partitioning-specitication, it will be necessary to ensure that the customized-layout also includes all the filesystems enumerated in the default behavior section.

<a name="Footnote2">3</a>: If specifying a partition/volume-size using the `FREE` or `100%FREE` method, doing so _must_ be done in the final tuple of the partition-string.

<a name="Footnote3">3</a>: To date, this has only been tested with the `/var/log/audit`/`auditVol` filesystem/volume
