#!/bin/bash

set -e
set -x

if [ "$1" == "" ]; then
  echo "At least one argument required. ex: run-in-container.sh /path/to/cmd arg1 arg2"
  exit 1
fi

# Pushing to Docker Hub requires login
DOCKER_IMAGE=${DOCKER_IMAGE:-bosh/integration}

# To push to the Pivotal GoCD Docker Registry (behind firewall):
# DOCKER_IMAGE=docker.gocd.cf-app.com:5000/bosh-container

echo "Running '$@' in docker container '$DOCKER_IMAGE'..."
docker run \
  -v $(pwd):/opt/bosh \
  -e RUBY_VERSION \
  -e DB \
  -e NUM_GROUPS \
  -e CODECLIMATE_REPO_TOKEN \
  -e COVERAGE \
  -e http_proxy=$http_proxy \
  -e https_proxy=$https_proxy \
  -e no_proxy=$no_proxy \
  $DOCKER_IMAGE \
  $@ \
  &

SUBPROC="$!"

trap "
  echo '--------------------- KILLING PROCESS'
  kill $SUBPROC

  echo '--------------------- KILLING CONTAINERS'
  docker ps -q | xargs docker kill
" SIGTERM SIGINT # gocd sends TERM; INT just nicer for testing with Ctrl+C

wait $SUBPROC
