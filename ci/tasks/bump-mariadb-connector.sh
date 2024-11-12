#!/usr/bin/env bash
set -euo pipefail

pushd bosh
  echo "${PRIVATE_YML}" > config/private.yml

  CONNECTOR_PREFIX="mariadb-connector-c"

  LATEST_MARIADB_CONNECTOR_BLOB_PATH=$(ls ../${CONNECTOR_PREFIX}-resource/*.tar.gz)
  LATEST_MARIADB_CONNECTOR_BLOB_KEY="mysql/$( basename "${LATEST_MARIADB_CONNECTOR_BLOB_PATH}" )"

  EXISTING_MARIADB_CONNECTOR_BLOB_KEY=$(bosh blobs | cut -f1 | grep "${CONNECTOR_PREFIX}" |  tr -d '[:space:]')

   if [ "${EXISTING_MARIADB_CONNECTOR_BLOB_KEY}" != "${LATEST_MARIADB_CONNECTOR_BLOB_KEY}" ]; then
    bosh add-blob --sha2 "${LATEST_MARIADB_CONNECTOR_BLOB_PATH}" "${LATEST_MARIADB_CONNECTOR_BLOB_KEY}"
    bosh remove-blob "${EXISTING_MARIADB_CONNECTOR_BLOB_KEY}"
    bosh upload-blobs

    git add .

    if [[ "$( git status --porcelain )" != "" ]]; then
      update_message="Updating blob ${EXISTING_MARIADB_CONNECTOR_BLOB_KEY} -> ${LATEST_MARIADB_CONNECTOR_BLOB_KEY}"
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
