#!/usr/bin/env bash

set -eux

VERSION=$( sed 's/\.0$//;s/\.0$//' candidate-version/number )
cp candidate-version/number bumped-candidate-version/number

export ROOT_PATH=$PWD
PROMOTED_REPO=$PWD/bosh-src-with-final

mv bosh-cli/alpha-bosh-cli-*-linux-amd64 bosh-cli/bosh-cli
export GO_CLI_PATH=$ROOT_PATH/bosh-cli/bosh-cli
chmod +x $GO_CLI_PATH

export DEV_RELEASE_PATH=$ROOT_PATH/bosh-dev-release/bosh*.tgz

git clone ./bosh-src-master $PROMOTED_REPO

pushd $PROMOTED_REPO
  git status

  cat >> config/private.yml <<EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: "$BLOBSTORE_ACCESS_KEY_ID"
    secret_access_key: "$BLOBSTORE_SECRET_ACCESS_KEY"
EOF

  $GO_CLI_PATH finalize-release --version $VERSION $DEV_RELEASE_PATH

  git add -A
  git status

  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"

  git commit -m "Adding final release $VERSION via concourse"

popd

cat <<EOF >bosh-src-with-final-tag/tag-name
v${VERSION}
EOF

cat <<EOF >bosh-src-with-final-tag/annotate-msg
Final release $VERSION tagged via concourse
EOF
