When switching from the old pipeline to the new one, don't forget to...

 * update `pipeline.yml` and change the bucket from `bosh-os-images-dev` to whatever the public bucket should be
 * update the tasks YAML which is point to tasks in the directory of `os-images`
 * rename this directory from `new`

# Pipeline Notes

    $ fly -t production set-pipeline -p bosh:os-image -c ci/pipelines/os-images/pipeline.yml \
      --load-vars-from <(lpass show -G "concourse:production pipeline:os-images" --notes)


# AWS

Concourse will want to publish its artifacts. Create an IAM user with the [required policy](iam_policy.json). Create buckets for OS Images, then give it a public-read policy...

    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::bosh-os-images/*"
            },
            {
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::bosh-os-images"
            }
        ]
    }
