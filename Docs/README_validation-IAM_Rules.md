In order to allow the validation template to upload its report files to an S3 bucket, it will be necessary to assign an instance-role to the template-launched instance. Permissions can be very wide, but it's generally recommended to use a "least-privileges" AWS object-access policy. Attaching a policy similar to the following:

~~~data
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::<BUCKET_NAME>"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::<BUCKET_NAME>/artifacts/validation",
                "arn:aws:s3:::<BUCKET_NAME>/artifacts/validation/*"
            ]
        }
    ]
}
~~~

To an instance will afford the instance S3 write access to _only_ the S3 `<BUCKET_NAME>/artifacts/validation` folder.
