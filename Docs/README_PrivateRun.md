# Using the Scripts - Private-Routed Network

The primary expected use case for these scripts is in a network that is able to to reach Internet-hosted resources. In such usage-contexts, the tools would typically be executed similarly to:

1. Launch an AMI to act as a build host
2. Attach a 20GiB EBS to the build host
3. Login to the build host and escalate privileges to root
4. Clone this project to the build host (make sure the destination filesystem allows script-execution)
5. Execute the following sequence:

~~~
    cd /PROJECT/CLONE/PATH ; \
      ./DiskSetup.sh -b /boot -v VolGroup00 -d /dev/xvdf ; \
      ./MkChrootTree.sh	/dev/xvdf ; \
      ./MkTabs.sh /dev/xvdf ; \
      ./ChrootBuild.sh -r <REPO_FILE_PATH> -b <REPOS_TO_ACTIVATE> ; \
      ./AWScliSetup.sh <CLI_URI_ROOT> <EPEL_FILE_PATH>; \
      ./ChrootCfg.sh ; \
      ./GrubSetup.sh /dev/xvdf ; \
      ./NetSet.sh ; \
      ./CleanChroot.sh ; \
      ./PreRelabel.sh	 ; \
      ./UmountChroot.sh
~~~

In the above:
- ChrootBuild.sh:
    - `<REPO_FILE_PATH>` is the path to an RPM containing private yum repo-definitions
    - `<REPOS_TO_ACTIVATE>` are the repos to activate from the private yum repo-definition. Typical yum globbing rules apply
- AWScliSetup.sh:
  - `<CLI_URI_ROOT>` gives the URI-path to the awscli-bundle.zip file (exclusive of the "awscli-bundle.zip" element) 
  - `<EPEL_FILE_PATH>` is the filesystem location for the RPM containing the private EPEL repository definition

Once the above sequence exits successfully, an AMI may be created from the target-disk (/dev/xvdf in the example above):

- For CentOS (or other "free" EL7 derivatives):
    1. Snapshot the target disk using either the AWS CLI or the AWS Web Console
    1. Register the EBS snapshot using either the AWS CLI or the AWS Web Console
    1. Launch a test-instance from the newly-created AMI and verify that if functions as expected.
- For RHEL:
    1. Shut down the build-host
    1. Detach boot EBS
    1. Detach build-EBS
    1. Re-attach build-EBS to boot EBS's original location
    1. Register an AMI from the stopped instance
    1. Launch a test-instance from the newly-created AMI and verify that if functions as expected:
        - Has an appropriate billingProducts meta-data tag set
        - Has access to license-related yum repositories


The OS-specific components can be further automated by using frameworks like [Packer](https://www.packer.io/). One such project that does this is Plus3 IT's [spel](https://github.com/plus3it/spel) project.
