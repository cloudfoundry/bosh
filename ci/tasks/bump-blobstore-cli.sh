#!/usr/bin/env bash
set -euo pipefail

case "${BLOBSTORE_TYPE}" in
dav)
  cli_name="davcli";;
gcs)
  cli_name="bosh-gcscli";;
s3)
  cli_name="s3cli";;
azure-storage)
  cli_name="azure-storage-cli";;
*)
  echo "Error: unknown BLOBSTORE_TYPE='${BLOBSTORE_TYPE}'; exiting"
  exit 1;;
esac

pushd bosh
  echo "${PRIVATE_YML}" > config/private.yml

  BLOB_PREFIX="${cli_name}"

  LATEST_BLOB_PATH=$(ls ../bosh-blobstore-cli/*cli*)
  LATEST_BLOB_KEY="${BLOB_PREFIX}/$( basename "${LATEST_BLOB_PATH}" )"
  # amd64 and arm64 blobs sit side by side; only replace the one for the
  # incoming blob's architecture.
  blob_arch="$(basename "${LATEST_BLOB_PATH}" | grep -o -E 'linux-[a-z0-9]+')"

  set +e
  EXISTING_BLOB_KEY=$(bosh blobs | cut -f1 | grep "${BLOB_PREFIX}" | grep -- "-${blob_arch}" | tr -d '[:space:]')
  set -e

  if [ "${EXISTING_BLOB_KEY}" != "${LATEST_BLOB_KEY}" ]; then
    bosh add-blob --sha2 "${LATEST_BLOB_PATH}" "${LATEST_BLOB_KEY}"
    if [ -n "${EXISTING_BLOB_KEY}" ]; then
      bosh remove-blob "${EXISTING_BLOB_KEY}"
    fi
    bosh upload-blobs

    git add .

    if [[ "$( git status --porcelain )" != "" ]]; then
      update_message="Updating blob ${EXISTING_BLOB_KEY} -> ${LATEST_BLOB_KEY}"
      git config user.name "${GIT_USER_NAME}"
      git config user.email "${GIT_USER_EMAIL}"

      echo ""
      echo "### Commit info"
      echo "    Message: '${update_message}'"
      echo ""
      git --no-pager diff --cached
      echo "^^^ Commit info"
      echo ""

      git commit --message "${update_message}"
    fi
  fi
popd
