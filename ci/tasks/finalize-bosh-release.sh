#!/usr/bin/env bash

set -eux

export FULL_VERSION=$(cat version/version)

export ROOT_PATH=$PWD
TARBALL_DIR=$PWD/release-tarball

mv bosh-cli/alpha-bosh-cli-*-linux-amd64 bosh-cli/bosh-cli
export GO_CLI_PATH=$ROOT_PATH/bosh-cli/bosh-cli
chmod +x $GO_CLI_PATH


pushd bosh-src

  set +x
  echo "$RELEASE_PRIVATE_YML" >> "config/private.yml"
  set -x

  $GO_CLI_PATH finalize-release --version $FULL_VERSION $TARBALL_DIR/tarball.tgz

  git add -A
  git status

  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"

  git commit -m "Adding final release $FULL_VERSION via concourse"

popd

cat <<EOF > release-metadata/tag-name
v${FULL_VERSION}
EOF

cat <<EOF > release-metadata/annotate-msg
Final release $FULL_VERSION tagged via concourse
EOF
