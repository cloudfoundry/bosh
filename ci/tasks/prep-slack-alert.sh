#!/usr/bin/env bash

set -e

echo '<!here>: $(cat build-metadata/build-pipeline-name)/$(cat build-metadata/build-job-name) failed in
<https://main.bosh-ci.cf-app.com/teams/main/pipelines/$(cat build-metadata/build-pipeline-name)/jobs/$(cat build-metadata/build-job-name)/builds/$(cat build-metadata/build-name)|build $(cat build-metadata/build-name)>' > slack-message/message

pushd bosh-src
  echo '```' >> ../slack-message/message
  git log -1 --format=fuller >> ../slack-message/message
  echo '```' >> ../slack-message/message
popd
