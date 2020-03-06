# Introduction
The scripts in this project are designed to ease the creation of LVM-enabled Enterprise Linux AMIs for use in AWS envrionments. It has been successfully tested with CentOS 7.x, Scientific Linux 7.x and Red Hat Enterprise Linux 7.x. It should work with other EL7-derived operating systems.

Note: The scripts _can_ also be used to generate bootstrap and/or recovery AMIs: non-LVMed AMIs intended to help generate the LVM-enabled AMIs or recover LVM-enabled instances. However, this functionality is only lightly tested. It is known to produce CentOS 7.x AMIs suitable for bootstrapping. It is also known to _not_ produce RHEL 7.x AMIs suitable for bootstrapping. As this is not the scripts' primary use-case, documentation for such is not included (though it should be easy enough for an experienced EL7 adminstrator to figure out from reading the scripts' contents).


## Table of Contents

* [Required RPMs](Docs/README_dependencies.md)
* [Scripts](Docs/README_scripts.md)
* How to run:
  * Select a suitable, generic AMI (e.g. one published by Red Hat, Inc. or CentOS.Org) to use to bootstrap the new AMI from (see the [AMI selection](Docs/README_BootstrapAMIselection.md) README)
  * Via build-instance hosted on a [Public Network](Docs/README_PublicRun.md)
  * Via build-instance hosted on a [Private Network](Docs/README_PrivateRun.md)
  * Instructions for [customizing filesystem layouts](Docs/README_CustomPartitioning.md) in resultant AMIs
  * Instructions for [selecting filesystem-type](Docs/README_XFS.md) in resultant AMIs
  * Instructions for [customizing RPM installations](Docs/README_AlternateBuildManifests.md) in resultant AMIs
* Verify that the resultant AMI supports the expected features (see the [Instance Verification](Docs/README_InstanceVerification.md) README)
* [Planned Enhancements](Docs/README_enhancements.md)

![Travis Build Status](https://travis-ci.org/ferricoxide/AMIgen7.svg?branch=master)
