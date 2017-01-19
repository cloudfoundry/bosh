#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

source /etc/profile.d/chruby.sh
chruby 2.1.2

check_param access_key_id
check_param secret_access_key
check_param s3_host
check_param s3_region

pushd bosh-src
  bosh sync blobs
  chmod +x ./blobs/s3cli/s3cli-*-amd64
popd

export S3CMD_CONFIG_FILE="${PWD}/s3cmd.s3cfg"
cat > "${S3CMD_CONFIG_FILE}" << EOF
[default]
access_key = ${access_key_id}
secret_key = ${secret_access_key}
bucket_location = ${s3_region}
host_base = ${s3_host}
host_bucket = %(bucket)s.${s3_host}
enable_multipart = True
multipart_chunk_size_mb = 15
use_https = True
EOF

function clean_up_bucket {
  local bucket=$1
  s3cmd --config ${S3CMD_CONFIG_FILE} rb s3://${bucket}
}

function clean_up {
  local bucket=$1
  s3cmd --config ${S3CMD_CONFIG_FILE} del s3://${bucket}/public
  clean_up_bucket ${bucket}
}

export AWS_ACCESS_KEY_ID=${access_key_id}
export AWS_SECRET_ACCESS_KEY=${secret_access_key}
export S3_HOST=${s3_host}

pushd bosh-src/src
  bundle install
  pushd bosh-director

    # Create bucket in US region
    bucket_name="bosh-blobstore-bucket-$RANDOM"
    echo -n "foobar" > public
    s3cmd --config ${S3CMD_CONFIG_FILE} --acl-public mb s3://${bucket_name}
    trap 'clean_up_bucket ${bucket_name}; exit 1' ERR
    retry_command "s3cmd --config ${S3CMD_CONFIG_FILE} --acl-public put public s3://${bucket_name}/"
    trap 'clean_up ${bucket_name}; exit 1' ERR

    export S3_BUCKET_NAME=${bucket_name}

    bundle exec rspec spec/functional/s3_spec.rb --tag general_s3
    if [ -n "$run_aws_tests" ]; then
      bundle exec rspec spec/functional/s3_spec.rb --tag aws_s3
    fi

    trap - ERR
    clean_up ${bucket_name}

    if [ -n "$run_aws_tests" ]; then
      # AWS Specific Testing: Recreate bucket in Frankfurt
      frankfurt_bucket_name="bosh-blobstore-bucket-$RANDOM"
      s3cmd --config ${S3CMD_CONFIG_FILE} --acl-public --region eu-central-1 mb s3://${frankfurt_bucket_name}
      trap 'clean_up_bucket ${frankfurt_bucket_name}; exit 1' ERR
      retry_command "s3cmd --config ${S3CMD_CONFIG_FILE} --acl-public put public s3://${frankfurt_bucket_name}/"
      trap 'clean_up ${frankfurt_bucket_name}; exit 1' ERR

      export S3_FRANKFURT_BUCKET_NAME=${frankfurt_bucket_name}

      bundle exec rspec spec/functional/s3_spec.rb --tag aws_frankfurt_s3
      trap - ERR
      clean_up ${frankfurt_bucket_name}
    fi

  popd
popd
