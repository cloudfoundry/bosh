#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

source /etc/profile.d/chruby.sh
chruby 2.1.2

check_param google_project
check_param google_json_key_data

function clean_up_bucket {
  local bucket=$1
  gsutil rm -rf gs://${bucket_name}/
}

function gcs_login {
  gcloud config set project $google_project

  echo $google_json_key_data > key.json
  gcloud auth activate-service-account --key-file=key.json
}

function gcs_logout {
  gcloud auth revoke
}

function setup_bucket {
    bucket_name="bosh-blobstore-bucket-$RANDOM"
    echo -n "foobar" > public
    gcs_login
    gsutil mb -c MULTI_REGIONAL -l us "gs://${bucket_name}"

    trap 'clean_up_bucket ${bucket_name}' EXIT

    gsutil acl set public-read "gs://${bucket_name}"
    gsutil cp -a public-read public "gs://${bucket_name}/"

    export GCS_BUCKET_NAME=${bucket_name}
}

setup_bucket

pushd bosh-src
  bosh sync blobs
  chmod +x ./blobs/bosh-gcscli/bosh-gcscli-*-amd64
popd

pushd bosh-src/src
  bundle install
popd

pushd bosh-src/src/bosh-director
  export GCS_SERVICE_ACCOUNT_KEY="${google_json_key_data}"
  bundle exec rspec spec/functional/gcs_spec.rb --tag general_gcs
popd
