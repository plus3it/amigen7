Creating an AMI stripped of any `billingProduct` metadata requires using the [`register-image`](https://docs.aws.amazon.com/cli/latest/reference/ec2/register-image.html) method. While the _basics_ of this method can be performed using the EC2 web console, it is necessary to use the CLI to ensure that [SRIOV](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sriov-networking.html) and [ENA](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking-ena.html] support are enabled within the created image (AMI).

To use this method, the AMI creator will need a couple of key pieces of information:
- ID of the EBS snapshot to register as an AMI
- Size of the source EBS of the snapshot to register as an AMI
- A suitable block-device-mappings JSON document

The last element should look something like:

    ~~~~
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
    ~~~~

This can be kept in a file.

The procedure for registering the image is:

1. Ensure that the EBS to create the AMI from is quiet. Detaching the EBS is the surest method for doing so. However, simply unmounting the EBS within any EC2 it's attached to _should be_ sufficient
2. Snapshot the EBS from which to create the AMI
3. When the snashot completes, execute the command:

~~~~
aws --region <AWS_REGION> ec2 register-image --virtualization-type hvm --architecture x86_64 \
  --ena-support --sriov-net-support simple --root-device-name /dev/sda1 --block-device-mappings \
  "$( sed -e 's/__SIZE__/<SOURCE_EBS_SIZE>/' -e 's/__SNAPSHOT_ID__/<YOUR_SNAPSHOT_ID>' </PATH/TO/AMI.JSON> )" \
  --name "<LOGICAL_NAME_FOR_AMI>"
~~~~
