#!/usr/bin/env bash

set -e

echo '<!here>: Build failed on with latest commit:' > slack-message/message

pushd bosh-src
  echo '```' >> ../slack-message/message
  git log -1 --format=fuller >> ../slack-message/message
  echo '```' >> ../slack-message/message
popd
