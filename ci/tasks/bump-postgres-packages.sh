#!/usr/bin/env bash
NEED_COMMIT=false

echo "${PRIVATE_YML}" > bosh/config/private.yml

set -e

status=$(head -n1 postgres-src/status 2>/dev/null || true)
case "${status}" in
  ready) ;;
  skip) tail -n +2 postgres-src/status; exit 0 ;;
  *) tail -n +2 postgres-src/status 2>/dev/null || true; echo "fetch status '${status}' is not ready"; exit 1 ;;
esac

pushd bosh
  CURRENT_BLOBS=$(bosh blobs)
  BLOB_PATH=$(ls ../postgres-src/postgresql-*.tar.gz)
  FILENAME=$( basename "${BLOB_PATH}" )
  OLD_BLOB_PATH=$(grep "postgresql-${MAJOR_VERSION}" config/blobs.yml  | cut -f1 -d:)
  if ! echo "${CURRENT_BLOBS}" | grep "${FILENAME}" ; then
    NEED_COMMIT=true
    echo "adding ${FILENAME}"
    bosh add-blob --sha2 "${BLOB_PATH}" "postgres/${FILENAME}"
    bosh remove-blob "${OLD_BLOB_PATH}"
    bosh upload-blobs
  fi

  if ${NEED_COMMIT}; then
    echo "-----> $(date): Creating git commit"
    git config user.name "${GIT_USER_NAME}"
    git config user.email "${GIT_USER_EMAIL}"
    git add .

    git --no-pager diff --cached
    if [[ "$( git status --porcelain )" != "" ]]; then
      git commit -am "Bump packages"
    fi
  fi
popd
