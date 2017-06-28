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
  gsutil rm gs://${bucket_name}/public # This may fail, which is fine.
  gsutil rb "gs://${bucket}"
}

function clean_up {
  local bucket=$1
  clean_up_bucket ${bucket}
}

gcloud config set project $google_project

echo $google_json_key_data > key.json
gcloud auth activate-service-account --key-file=key.json

export GCS_SERVICE_ACCOUNT_KEY=$google_json_key_data

pushd bosh-src/src
  bundle install
  pushd bosh-director

    # Create bucket in US region
    bucket_name="bosh-blobstore-bucket-$RANDOM"
    echo -n "foobar" > public
    gsutil mb -c MULTI_REGIONAL -l us gs://${bucket_name}
    # gsutil acl ch -u AllUsers:R gs://${bucket_name}
    gsutil iam ch allUsers:objectViewer gs://${bucket_name}
    gsutil iam ch allUsers:legacyObjectReader gs://${bucket_name}
		gsutil iam ch allUsers:legacyBucketReader gs://${bucket_name}
		echo "waiting for IAM to propagate" && \
		until curl -s \
			https://storage.googleapis.com/${bucket_name}/non-existent \
			| grep -q "NoSuchKey"; do sleep 1; done; \
    trap 'clean_up_bucket ${bucket_name}; exit 1' ERR
    gsutil cp public gs://${bucket_name}/public
    retry_command "gsutil acl ch -r -u AllUsers:R gs://${bucket_name}/public"
    trap 'clean_up ${bucket_name}; exit 1' ERR

    export GCS_BUCKET_NAME=${bucket_name}

    bundle exec rspec spec/functional/gcs_spec.rb --tag general_gcs

    trap - ERR
    clean_up ${bucket_name}

  popd
popd
