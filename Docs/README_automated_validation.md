# Verification

The validation of the generated AMIs can be automated via AWS's CloudFormation functionality. This project includes a [suitable template](Validation_child-EC2_el7.tmplt.json) to automate the validation procedures and to generate and post a validation-report to an S3-hosted folder.

## Procedure:

### CLI-based:

1. (optional) Upload the [validation template](Validation_child-EC2_el7.tmplt.json) to an S3 bucket.
1. Create parameters file. This file contains a list of key-value pairs that the CloudFormation CLI uses to fill in a template's input fields. The parameters file content looks like:

    ```json
[
  {
    "ParameterKey": "KeyName1",
    "ParameterValue": "KeyVal1"
  },
    ```
[...elided...]
    ```json
  {
    "ParameterKey": "KeyNameN",
    "ParameterValue": "KeyValN"
  }
]
    ```

    Look at the [example file](validation-generic.json) if the above is not clear.

1. Update the parameters file contents with values appropriate to your testing-environment.

    - `AmiDistro`: This will be a value of either `CentOS` or `RedHat`.
    - `AmiId`: This will be the image-ID of the AMI you wish to validate.
    - `BucketName`: This is the name of the S3 bucket that audit-artifacts are uploaded. By default, the audit-reports will be written to the `s3://<BUKKITNAME>/artifacts/validation/` bucket-folder.
    - `InstanceRole`: An instance-role to assign to the testing instance. Note that, in order to write the eport-file to S3, the instance-role will need to have [write permissions](README_validation-IAM_Rules.md) to `s3://<BUKKITNAME>/artifacts/validation/`.
    - `InstanceType`: The instance-type that the test-instance will be launched as. Recommend `m4.large` (other instance-types may be selected but may cause the 10Gbps-support test to report lack of 10Gbps support).
    - `KeyPairName`: This is the logical-name of the provisioning key. This key will allow the tester to SSH into the default-user's account. A valid keyname must be given, even if there's no intention to login to the test-instance.
    - `NoPublicIp`: Whether to assign a public IP to the instance. Set to "false" if intending to SSH into the host from a host outside of AWS.
    - `NoReboot`: Whether to reboot the instance or not. Set to "true" to prevent rebooting.
    - `RootEBSsize`: Size of the root EBS volume to launch the instance with. Valid values are from 21-49 (recommend "25").
    - `SecurityGroupIds`: This is either a single value or comma-delimited list of values of valid security-group IDs for the testing-account.
    - `SubnetIds`: This is the subnet to launch the test-instance into.

1. Ensure that AWS credentials for your account/role are set.
1. Ensure that the `aws` command is in your path (execute `aws --version`).
1. Create the test instance from the template and parameter file:

    ```bash
aws --profile <PROFILE> cloudformation --region <REGION> \
   --template-url <TEMPLATE_URL> \
   --parameters "file://<PATH>/<to>/<PARAM>/File
    ```

If all goes well, the `aws cloudformtation` command will result in an output message similar to:

```json
{
    "StackId": "arn:aws:cloudformation:us-east-2:NNNNNNNNNNNN:stack/TEST-STDIN/1db002e4-d0dd-1e61-ba4b-05052c82a405"
}
```

### Web UI-based:

1. (optional) Upload the [validation template](Validation_child-EC2_el7.tmplt.json) to an S3 bucket.
1. Open the CloudFormation service-page:

    <img src="https://cloud.githubusercontent.com/assets/7087031/22160753/0d691844-df15-11e6-92be-37222f280101.png" alt="amivalidate-step1" width="75%" height="75%">

    Then click on the "Create" button.

1. Place the URL to the template in the `Specify an Amazon S3 template URL` box.

    <img src="https://cloud.githubusercontent.com/assets/7087031/22160754/0d6a9b1a-df15-11e6-90fd-594cdaa7a91e.png" alt="amivalidate-step2" width="75%" height="75%">

    Then click on the "Next" button.

1. On the `Specify Details` page:

    <img src="https://cloud.githubusercontent.com/assets/7087031/22161151/295de7da-df17-11e6-9a7a-b55a85777473.png" alt="amivalidate-step3" width="75%" height="75%">

    Ensure that each box contains valid values. Then click on the "Next" button.

1. On the `Options` page:

    <img src="https://cloud.githubusercontent.com/assets/7087031/22160758/0d722e52-df15-11e6-849e-d2633e70b5ff.png" alt="amivalidate-step4" width="75%" height="75%">

   (Optional) Check the `No` radio-box in the `Rollback on failure` section. Doing this should allow you to investigate what went wrong in the instance should the stack-creation fail.

    Then click on the "Next" button.

1. Verify that the data on the `Review` page looks correct:

    <img src="https://cloud.githubusercontent.com/assets/7087031/22160756/0d6c3b0a-df15-11e6-8766-204d2e215a42.png" alt="amivalidate-step5" width="75%" height="75%">

    Then click on the "Next" button. This will cause CloudFormation to attempt assemble your AMI-validation stack.

1. Once CloudFormation kicks off the stack-assembly process, the Web UI will return to the `Stacks` page:

    <img src="https://cloud.githubusercontent.com/assets/7087031/22160757/0d6dd6b8-df15-11e6-8777-c1120c846c02.png" alt="amivalidate-step6" width="75%" height="75%">

    The new stack should show up in either a `CREATE_IN_PROCESS` or `CREATE_COMPLETE` stage.

    Note: If the page renders and your stack does not appear, hit the page-refresh button. 

1. Click on the stack-name if you want to see the details of the stack-creation process:

    <img src="https://cloud.githubusercontent.com/assets/7087031/22160755/0d6c1e5e-df15-11e6-8778-d05fec1ec3ba.png" alt="amivalidate-step7" width="75%" height="75%">

## Results
Allow 3-5 minutes to pass after receiving the StackId (if using the CLI method) or the Web UI shows the stack in `CREATE_COMPLETE` state. Look in `s3://<BUCKET_NAME>/artifacts/validation/` for a new audit file. The audit-file will take a name similar to: `audit_<AMI_ID>-<YYYYMmmDD>.txt` (where `AMI_ID` is the ID of the AMI that was validated and `YYYMmmDD` will be something like `2017Jan11`). The file's contents will be similar to:

```
Check 10Gbps support: Found 10Gbps support
==========
Check EBS-resizing: Root EBS was resized
==========
Check for AWS packages:
   aws-apitools-cfn-1.0.12-1.0.el7.noarch
   aws-apitools-as-1.0.61.6-1.0.el7.noarch
   aws-amitools-ec2-1.5.9-0.0.el7.noarch
   aws-apitools-mon-1.0.20.0-1.0.el7.noarch
   aws-scripts-ses-2014.05.14-1.2.el7.noarch
   aws-apitools-iam-1.5.0-1.2.el7.noarch
   aws-apitools-ec2-1.7.3.0-1.0.el7.noarch
   aws-cfn-bootstrap-1.4-15.9.el7.noarch
   aws-apitools-common-1.1.0-1.9.el7.noarch
   aws-apitools-rds-1.19.002-1.0.el7.noarch
   aws-apitools-elb-1.0.35.0-1.0.el7.noarch
==========
Check AWS CLI version:
   aws-cli/1.11.58 Python/2.7.5 Linux/3.10.0-514.10.2.el7.x86_64 botocore/1.5.21
==========
Check RPM repo-access:
repo id                       repo name                           status
C7.0.1406-base/x86_64         CentOS-7.0.1406 - Base              disabled
C7.0.1406-centosplus/x86_64   CentOS-7.0.1406 - CentOSPlus        disabled
C7.0.1406-extras/x86_64       CentOS-7.0.1406 - Extras            disabled
C7.0.1406-fasttrack/x86_64    CentOS-7.0.1406 - CentOSPlus        disabled
C7.0.1406-updates/x86_64      CentOS-7.0.1406 - Updates           disabled
C7.1.1503-base/x86_64         CentOS-7.1.1503 - Base              disabled
C7.1.1503-centosplus/x86_64   CentOS-7.1.1503 - CentOSPlus        disabled
C7.1.1503-extras/x86_64       CentOS-7.1.1503 - Extras            disabled
C7.1.1503-fasttrack/x86_64    CentOS-7.1.1503 - CentOSPlus        disabled
C7.1.1503-updates/x86_64      CentOS-7.1.1503 - Updates           disabled
C7.2.1511-base/x86_64         CentOS-7.2.1511 - Base              disabled
C7.2.1511-centosplus/x86_64   CentOS-7.2.1511 - CentOSPlus        disabled
C7.2.1511-extras/x86_64       CentOS-7.2.1511 - Extras            disabled
C7.2.1511-fasttrack/x86_64    CentOS-7.2.1511 - CentOSPlus        disabled
C7.2.1511-updates/x86_64      CentOS-7.2.1511 - Updates           disabled
base/7/x86_64                 CentOS-7 - Base                     enabled: 9,363
base-debuginfo/x86_64         CentOS-7 - Debuginfo                disabled
base-source/7                 CentOS-7 - Base Sources             disabled
c7-media                      CentOS-7 - Media                    disabled
centosplus/7/x86_64           CentOS-7 - Plus                     disabled
centosplus-source/7           CentOS-7 - Plus Sources             disabled
cr/7/x86_64                   CentOS-7 - cr                       disabled
epel/x86_64                   Extra Packages for Enterprise Linux disabled
epel-debuginfo/x86_64         Extra Packages for Enterprise Linux disabled
epel-source/x86_64            Extra Packages for Enterprise Linux disabled
epel-testing/x86_64           Extra Packages for Enterprise Linux disabled
epel-testing-debuginfo/x86_64 Extra Packages for Enterprise Linux disabled
epel-testing-source/x86_64    Extra Packages for Enterprise Linux disabled
extras/7/x86_64               CentOS-7 - Extras                   enabled:   311
extras-source/7               CentOS-7 - Extras Sources           disabled
fasttrack/7/x86_64            CentOS-7 - fasttrack                disabled
updates/7/x86_64              CentOS-7 - Updates                  enabled: 1,107
updates-source/7              CentOS-7 - Updates Sources          disabled
repolist: 10,781
==========
Active swap device(s): 
   /dev/dm-1
==========
Mounted partition for /boot was found
==========
/tmp is mounted from tmpfs
==========
Check booted kernel: 
   Name        : kernel
   Version     : 3.10.0
   Release     : 514.10.2.el7
   Architecture: x86_64
   Install Date: Wed 08 Mar 2017 05:39:07 PM UTC
   Group       : System Environment/Kernel
   Size        : 154822974
   License     : GPLv2
   Signature   : RSA/SHA256, Fri 03 Mar 2017 11:37:02 AM UTC, Key ID 24c6a8a7f4a80eb5
   Source RPM  : kernel-3.10.0-514.10.2.el7.src.rpm
   Build Date  : Fri 03 Mar 2017 12:55:11 AM UTC
   Build Host  : kbuilder.dev.centos.org
   Relocations : (not relocatable)
   Packager    : CentOS BuildSystem <http://bugs.centos.org>
   Vendor      : CentOS
   URL         : http://www.kernel.org/
   Summary     : The Linux kernel
   Description :
   The kernel package contains the Linux kernel (vmlinuz), the core of any
   Linux operating system.  The kernel handles the basic functions
   of the operating system: memory allocation, process allocation, device
   input and output, etc.
==========
Check SELinux mode: Enforcing
==========
Check FIPS mode: Enabled
==========
Check Xen root-dev mapping: enabled
```
