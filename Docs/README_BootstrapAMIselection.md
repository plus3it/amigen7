In order to produce AMIs that support desired features, it is important that the AMI used to bootstrap from supports those same features:

* For candidate RHEL 7 bootstrap AMIs: ensure that the AMI has a valid `billingProducts` value set (typically `bp-6fa54006`). This gives resultant AMIs access to the Red Hat RPM repositories. 
* For all EL 7 bootstrap AMIs: ensure that the AMI has SriovNetSupport support enabled. This gives resultant AMIs the ability to produce instances that support 10Gbps networking mode.

    ~~~
$ aws --profile <PROFILE_NAME> ec2 --region <REGION> describe-image-attribute --image-id <AMI_ID> \
  --attribute sriovNetSupport
{
    "SriovNetSupport": {
        "Value": "simple"
    },
    "ImageId": "<AMI_ID>"
}
    ~~~

**Note:** for AMIs not owned by your account, you likely will not have sufficient permissions to read the AMI's attribute values.
