#!/usr/bin/env bash
set -euo pipefail

case "${BLOBSTORE_TYPE}" in
dav)
  cli_name="davcli";;
gcs)
  cli_name="bosh-gcscli";;
s3)
  cli_name="s3cli";;
*)
  echo "Error: unknown BLOBSTORE_TYPE='${BLOBSTORE_TYPE}'; exiting"
  exit 1;;
esac

pushd bosh-src
  echo "${PRIVATE_YML}" > config/private.yml

  LATEST_CLI_BLOB_PATH=$(ls ../bosh-blobstore-cli/*cli*)
  LATEST_CLI_BLOB_KEY="${cli_name}/$( basename "${LATEST_CLI_BLOB_PATH}" )"

  EXISTING_CLI_BLOB_KEY=$(bosh blobs | cut -d ' ' -f1 | grep "${cli_name}")

   if [ "${EXISTING_CLI_BLOB_KEY}" != "${LATEST_CLI_BLOB_KEY}" ]; then
    bosh add-blob --sha2 "${LATEST_CLI_BLOB_PATH}" "${LATEST_CLI_BLOB_KEY}"
    bosh remove-blob "${EXISTING_CLI_BLOB_KEY}"

    git add .

    git --no-pager diff --cached
#    TODO - uncomment
    if [[ "$( git status --porcelain )" != "" ]]; then
      git config user.name "${GIT_USER_NAME}"
      git config user.email "${GIT_USER_EMAIL}"
      git commit --message "Updating blob ${EXISTING_CLI_BLOB_KEY} -> ${LATEST_CLI_BLOB_KEY}"

#      bosh upload-blobs
    fi
  fi
popd
