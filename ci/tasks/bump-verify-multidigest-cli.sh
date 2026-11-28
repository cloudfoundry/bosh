#!/usr/bin/env bash
set -euo pipefail

pushd bosh
  echo "${PRIVATE_YML}" > config/private.yml

  BLOB_PREFIX="verify-multidigest"

  LATEST_BLOB_PATH=$(ls ../verify-multidigest-cli/verify-multidigest-*)
  LATEST_BLOB_KEY="${BLOB_PREFIX}/$( basename "${LATEST_BLOB_PATH}" )"
  # amd64 and arm64 blobs sit side by side; only replace the one for the
  # incoming blob's architecture.
  blob_arch="$(basename "${LATEST_BLOB_PATH}" | grep -o -E 'linux-[a-z0-9]+')"

  # A failing "bosh blobs" stops the script; only "no match" means no blob yet.
  all_blob_keys="$(bosh blobs | cut -f1)"
  EXISTING_BLOB_KEY=$(printf '%s\n' "${all_blob_keys}" | { grep "${BLOB_PREFIX}" || true; } | { grep -- "-${blob_arch}" || true; } | tr -d '[:space:]')

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
