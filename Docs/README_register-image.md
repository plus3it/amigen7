# Register Image

In order to register an AMI that has been stripped of any `billingProduct` metadata, it will be necessary to register the image from an EBS snapshot. Registering from snapshot can be done either from the EC2 Web Console or the AWS CLI. However, in order to ensure that support for ENA and SRIOV is enabled within the registered image, the AWS CLI must be used.

## Notes

Properly registering an image from snapshot requires informing the registration-tool about the desired storage-configuration of the resultant image. This is done by passing a JSON string to the registration-utility. To make this easier, it is recommended to maintain configuration JSON-content in a file similar to the following:

    [
        {
            "DeviceName": "/dev/sda1",
            "Ebs": {
                "DeleteOnTermination": true,
                "SnapshotId": "__SNAPSHOT_ID__",
                "VolumeSize": __SIZE__,
                "VolumeType": "gp2"
            }
        }
    ]

Using the above JSON document, it will allow the use of on-the-fly editing of the JSON document's content when referencing with the registration-tool.

For the actual registration step, the AMI-creator will need to know:
- The region hosting the AMI-builder EC2 instance
- The size of the original template-EBS
- The ID of a snapshot made from the finished template-EBS

## Procedure

The following assumes that the template-EBS has already been built using the tools included in this project.

1. Ensure that the template-EBS is quiesced. This can be done either by detaching the template-EBS from its builder-EC2 or simply unmounting all filesystems hosted by the template-EBS.
1. Take note of the template-EBS's size.
1. Create a snapshot of the template-EBS.
1. When the snapshot has completed, take note of its ID
1. Using the previously recorded template-EBS size and snapshot-ID, invoke the image registration-utility similarly to the following:
    ~~~~
    aws --region ${REGION} ec2 register-image --virtualization-type hvm --architecture x86_64 \
      --ena-support --sriov-net-support simple --root-device-name /dev/sda1 --block-device-mappings \
      "$( sed -e 's/__SIZE__/<SOURCE_EBS_SIZE>/' -e 's/__SNAPSHOT_ID__/<SNAPSHOT_ID>' /tmp/AMI.json )"
      --name "<NAME_TO_ASSIGN_TO_IMAGE>"
    ~~~~

To explain:

* `aws`: Invoke the AWS commandline utility
* `REGION`: The name of the AWS service region (e.g., "us-east-1") in which the registration-utility should create the AMI
* `ec2 register-image`: The AWS CLI sub-command that invokes the image-registration routines
* `--virtualization-type`: Instructs the registration-utility to create an AMI that is compatible with the `hvm` hypervisor-type
* `--architecture`: Instructs the registration-utility to create an AMI suitable for hosting operating systems that rely on the `x86_64` CPU architecture
* `--ena-support`: Instructs the registration-utility to create an AMI that supports ENA extensions
* `--sriov-net-support simple`: Instructs the registration-utility to create an AMI that supports SRIOV extensions in `simple` mode
* `--root-device-name`: Name of the EC2-external device-name of the root EBS volume. This value should always be `/dev/sda1`
* `--block-device-mappings`: Instructs the registration-utility to create an AMI that contains a disk set up as described in the immediately-following JSON-formatted string.
* `sed...`: A BASH-centric method for creating a JSON-formatted string from a JSON-formatted file hosted at `/tmp/AMI.json`. The embedded `sed` command substitutes the values of `<SOURCE_EBS_SIZE>` and `<SNAPSHOT_ID>` for the document-contained strings, `__SIZE__` and `__SNAPSHOT_ID__`, respectively
* `--name`: Instructs the registration-utility to create an AMI with the name given via the `<NAME_TO_ASSIGN_TO_IMAGE>` string
