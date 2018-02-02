#!/usr/bin/env bash

set -e

echo "<!here>: ${BUILD_PIPELINE_NAME}/${BUILD_JOB_NAME} failed in
<https://main.bosh-ci.cf-app.com/teams/main/pipelines/${BUILD_PIPELINE_NAME}/jobs/${BUILD_JOB_NAME}/builds/${BUILD_NAME}|build ${BUILD_NAME}>" > slack-message/message

pushd bosh-src
  git log -1 --format=fuller >> ../slack-message/message
popd
