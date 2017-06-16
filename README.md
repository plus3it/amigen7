# Introduction
The scripts in this project are designed to ease the creation of LVM-enabled Enterprise Linux AMIs for use in AWS envrionments. It has been successfully tested with CentOS 7.x, Scientific Linux 7.x and Red Hat Enterprise Linux 7.x. It should work with other EL7-derived operating systems.


## Table of Contents

* [Required RPMs](Docs/README_dependencies.md)
* [Scripts](Docs/README_scripts.md)
* How to run:
  * Select a suitable, generic AMI (e.g. one published by Red Hat, Inc. or CentOS.Org) to use to bootstrap the the new AMI from (see the [AMI selection](Docs/README_BootstrapAMIselection.md) README)
  * Via build-instance hosted on a [Public Network](Docs/README_PublicRun.md)
  * Via build-instance hosted on a [Private Network](Docs/README_PrivateRun.md)
* Verify that the resultant AMI supports the expected features (see the [Instance Verification](Docs/README_InstanceVerification.md) README)
* [Planned Enhancements](Docs/README_enhancements.md)

![Travis Build Status](https://travis-ci.org/ferricoxide/AMIgen7.svg?branch=master)
