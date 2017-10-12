#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

source /etc/profile.d/chruby.sh
chruby 2.1.2

check_param google_project
check_param google_json_key_data

pushd bosh-src
  bosh sync blobs
  chmod +x ./blobs/bosh-gcscli/bosh-gcscli-*-amd64
popd

function clean_up_bucket {
  local bucket=$1
  gsutil rm -rf gs://${bucket_name}/
}

gcloud config set project $google_project

echo $google_json_key_data > key.json
gcloud auth activate-service-account --key-file=key.json

export GCS_SERVICE_ACCOUNT_KEY=$google_json_key_data

pushd bosh-src/src
  bundle install
  pushd bosh-director
    bucket_name="bosh-blobstore-bucket-$RANDOM"
    echo -n "foobar" > public
    gsutil mb -c MULTI_REGIONAL -l us gs://${bucket_name}

    trap 'clean_up_bucket ${bucket_name}; exit 1' EXIT

    gsutil acl ch -u allUsers:R gs://${bucket_name}
    gsutil cp public gs://${bucket_name}/public

    echo "waiting for IAM to propagate" && \
      until curl -s \
        https://storage.googleapis.com/${bucket_name}/non-existent \
          | grep -q "NoSuchKey"; do sleep 1; done; \

    export GCS_BUCKET_NAME=${bucket_name}

    bundle exec rspec spec/functional/gcs_spec.rb --tag general_gcs
  popd
popd
