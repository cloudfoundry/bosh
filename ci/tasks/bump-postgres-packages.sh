#/usr/bin/env bash
NEED_COMMIT=false

echo "${PRIVATE_YML}" > bosh-src/config/private.yml

set -e

pushd postgres-src
  IFS=,; for VERSION in $MAJOR_VERSIONS; do 
    MINOR=$(git tag --list  "REL_${VERSION}_[0-9]*" | cut -f3 -d_ | sort -n | tail -1 )
    echo "creating package for: Major $VERSION.$MINOR";
    git checkout "REL_${VERSION}_${MINOR}"
    tar -czf ../postgresql-${VERSION}.${MINOR}.tar.gz --exclude=.git* .
  done
popd

pushd bosh-src
  CURRENT_BLOBS=$(bosh blobs)
  IFS=,; for VERSION in ${MAJOR_VERSIONS}; do 
    BLOB_PATH=$(ls ../postgresql-${VERSION}*)
    FILENAME=$( echo ${BLOB_PATH} | cut -f2 -d'/' )
    OLD_BLOB_PATH=$(cat config/blobs.yml  | grep "postgresql-${VERSION}" | cut -f1 -d:)
    if ! echo "${CURRENT_BLOBS}" | grep "${FILENAME}" ; then
      NEED_COMMIT=true
      echo "adding ${FILENAME}"
      bosh add-blob --sha2 "${BLOB_PATH}" "postgres/${FILENAME}"
      bosh remove-blob ${OLD_BLOB_PATH}
      bosh upload-blobs
    fi
  done

  if ${NEED_COMMIT}; then
    echo "-----> $(date): Creating git commit"
    git config user.name "$GIT_USER_NAME"
    git config user.email "$GIT_USER_EMAIL"
    git add .

    git --no-pager diff --cached
    if [[ "$( git status --porcelain )" != "" ]]; then
      git commit -am "Bump packages"
    fi
  fi
popd
