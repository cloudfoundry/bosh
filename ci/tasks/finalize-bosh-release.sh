#!/usr/bin/env bash

set -eux

export FULL_VERSION=$(cat version/version)

export ROOT_PATH=$PWD
PROMOTED_MASTER=$PWD/bosh-master-with-final
TARBALL_DIR=$PWD/release-tarball

mv bosh-cli/alpha-bosh-cli-*-linux-amd64 bosh-cli/bosh-cli
export GO_CLI_PATH=$ROOT_PATH/bosh-cli/bosh-cli
chmod +x $GO_CLI_PATH

git clone ./bosh-master $PROMOTED_MASTER

pushd $PROMOTED_MASTER
  git pull origin master
  git status

  echo "$RELEASE_PRIVATE_YML" >> "config/private.yml"

  $GO_CLI_PATH finalize-release --version $FULL_VERSION $TARBALL_DIR/tarball.tgz

  git add -A
  git status

  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"

  git commit -m "Adding final release $FULL_VERSION via concourse"

popd

cat <<EOF >bosh-master-with-final/tag-name
v${FULL_VERSION}
EOF

cat <<EOF >bosh-master-with-final/annotate-msg
Final release $FULL_VERSION tagged via concourse
EOF
