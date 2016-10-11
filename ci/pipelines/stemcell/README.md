# Pipeline Notes

    $ fly -t production set-pipeline -c pipeline.yml  -p stemcell-new-dev-temp \
      --load-vars-from <( lpass show --notes "concourse:production pipeline:stemcell-new-dev-temp" )


# AWS

Concourse will want to publish its artifacts. Create an IAM user with the [required policy](iam_policy.json). Create buckets for stemcells, then give it a public-read policy...

    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::bosh-core-stemcells-dev/*"
            },
            {
                "Sid": "",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::bosh-core-stemcells-dev"
            }
        ]
    }
