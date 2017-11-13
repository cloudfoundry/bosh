#!/usr/bin/env bash

set -eux

export FULL_VERSION=$(cat candidate-version/version)
cp candidate-version/version bumped-candidate-version/version

export ROOT_PATH=$PWD
PROMOTED_MASTER=$PWD/bosh-master-with-final
PROMOTED_SRC=$PWD/bosh-src-with-bumped-version

mv bosh-cli/alpha-bosh-cli-*-linux-amd64 bosh-cli/bosh-cli
export GO_CLI_PATH=$ROOT_PATH/bosh-cli/bosh-cli
chmod +x $GO_CLI_PATH

export DEV_RELEASE_PATH=$ROOT_PATH/bosh-dev-release/bosh*.tgz

git clone ./bosh-master $PROMOTED_MASTER

pushd $PROMOTED_MASTER
  git status

  cat >> config/private.yml <<EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: "$BLOBSTORE_ACCESS_KEY_ID"
    secret_access_key: "$BLOBSTORE_SECRET_ACCESS_KEY"
EOF

  $GO_CLI_PATH finalize-release --version $FULL_VERSION $DEV_RELEASE_PATH

  git add -A
  git status

  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"

  git commit -m "Adding final release $FULL_VERSION via concourse"

popd

git clone ./bosh-src $PROMOTED_SRC

pushd $PROMOTED_SRC
  git status

  sed -i "s/\['version'\] = ..*/['version'] = '$FULL_VERSION'/" jobs/director/templates/director.yml.erb.erb
  sed -i "s/\['version'\])\.to eq..*/['version']).to eq('$FULL_VERSION')/" spec/director.yml.erb.erb_spec.rb

  git add -A
  git status

  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"

  git commit -m "Bump version $FULL_VERSION via concourse"

popd

cat <<EOF >bosh-src-with-bumped-version-tag/tag-name
v${FULL_VERSION}
EOF

cat <<EOF >bosh-src-with-bumped-version-tag/annotate-msg
Final release $FULL_VERSION tagged via concourse
EOF
