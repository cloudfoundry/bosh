#!/usr/bin/env bash
set -euo pipefail

pushd bosh-src
  echo "${PRIVATE_YML}" > config/private.yml

  BLOB_PREFIX="nats"

  LATEST_BLOB_PATH=$(ls ../nats-server-github-release/nats-server-*)
  LATEST_BLOB_KEY="${BLOB_PREFIX}/$( basename "${LATEST_BLOB_PATH}" )"

  EXISTING_BLOB_KEY=$(bosh blobs | cut -f1 | grep "${BLOB_PREFIX}" |  tr -d '[:space:]')

   if [ "${EXISTING_BLOB_KEY}" != "${LATEST_BLOB_KEY}" ]; then
    bosh add-blob --sha2 "${LATEST_BLOB_PATH}" "${LATEST_BLOB_KEY}"
    bosh remove-blob "${EXISTING_BLOB_KEY}"
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
