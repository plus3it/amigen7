In order to produce AMIs that support desired features, it is important that the AMI used to bootstrap from supports those same features:

* For candidate RHEL 7 bootstrap AMIs: ensure that the AMI has a valid `billingProducts` value set (typically `bp-6fa54006`). This gives resultant AMIs access to the Red Hat RPM repositories. At this point in time,  a way to use the AWS APIs/utilities to pull attribute information directly from an unlaunched AMI has yet to be identified. The only currently-known way is per the notes in this [BlogSpot post](https://thjones2.blogspot.com/2015/03/so-you-dont-want-to-byol.html).
* For all EL 7 bootstrap AMIs:
    * Ensure that the AMI has SriovNetSupport support enabled. This gives resultant AMIs the ability to produce instances that support 10Gbps networking mode.
        ~~~
        $ aws --profile <PROFILE_NAME> --region <REGION> ec2 describe-image-attribute --image-id <AMI_ID> \
          --attribute sriovNetSupport
        {
            "SriovNetSupport": {
                "Value": "simple"
            },
            "ImageId": "<AMI_ID>"
        }
        ~~~
    * Ensure that the AMI has Elastic Network Adapter (ENA) support enabled. This allows the resultant AMIs (EL 7.4.1708 or newer) to take advantage of instance-types with 20Gbps+ networking mode.
        ~~~
        $ aws --profile <PROFILE_NAME>  --region <REGION> ec2 describe-images --image-id <AMI_ID> \
          --query 'Images[].EnaSupport'
        [
            true
        ]
        ~~~
**Note:** for AMIs not owned by your account, you likely will not have sufficient permissions to read the AMI's attribute values.
