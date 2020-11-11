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
      ./ChrootBuild.sh -r <REPO_FILE_PATH> -b <REPOS_TO_ACTIVATE> -e rpm1,rpm2,@rpmgroup ; \
      ./AWScliSetup.sh <CLI_URI_ROOT> <EPEL_FILE_PATH>; \
      ./ChrootCfg.sh ; \
      ./GrubSetup.sh /dev/xvdf ; \
      ./NetSet.sh ; \
      ./CleanChroot.sh ; \
~~~
Optionally, run:
~~~
      ./SetRootPW.sh <PASSWORD_STRING>; \
~~~
If setting the root user's password is desired. This will typically be used in non-cloud environments (e.g., VMware vSphere)
~~~
      ./PreRelabel.sh	 ; \
      ./Umount.sh
~~~

In the above:
- ChrootBuild.sh:
    - `<REPO_FILE_PATH>` is the path to an RPM containing private yum repo-definitions
    - `<REPOS_TO_ACTIVATE>` are the repos to activate from the private yum repo-definition. Typical yum globbing rules apply
- AWScliSetup.sh:
  - `<CLI_URI_ROOT>` gives the URI-path to the awscli-bundle.zip file (exclusive of the "awscli-bundle.zip" element) 
  - `<EPEL_FILE_PATH>` is the filesystem location for the RPM containing the private EPEL repository definition

Once the above sequence exits successfully, an AMI may be created from the target-disk (/dev/xvdf in the example above):

1. Shut down the build-host
1. Detach boot EBS
1. Detach build-EBS
1. Re-attach build-EBS to boot EBS's original location
1. Create or register an AMI:
    * If you wish to inherit an attribute like a [`billingProducts` tag](https://thjones2.blogspot.com/2015/03/so-you-dont-want-to-byol.html), use the [`register-image`](README_register-image.md) AMI-creation method to create an AMI from the stopped image.
    * If you wish to ensure that the AMI does not inherit an attribute like a `billingProducts`, create a snapshot of the boot EBS and use the `create-image` AMI-creation method to create an AMI from the snapshot.

1. Launch a test-instance from the newly-created AMI and verify that it functions as expected.

The OS-specific components can be further automated by using frameworks like [Packer](https://www.packer.io/). One such project that does this is Plus3 IT's [spel](https://github.com/plus3it/spel) project.
