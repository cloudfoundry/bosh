#!/bin/bash -l

set -e -x

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true

env | sort

export TMPDIR=/mnt/ci-tmp
mkdir -p $TMPDIR

(
  cd "$(git rev-parse --show-toplevel)"
  # Ensure that any modifications or stray files are removed
  git clean -df
  git checkout .

  # BUILD_FLOW_GIT_COMMIT gets set in the bosh_build_flow jenkins jobs.
  # This ensures we check out the same git commit for all jenkins jobs in the flow.
  if [ -n "$BUILD_FLOW_GIT_COMMIT" ]; then
    git checkout $BUILD_FLOW_GIT_COMMIT
    git submodule update --init --recursive
    git clean -dff
  fi
)

echo "--- Starting bundle install in `pwd` @ `date` ---"
if [ -f .bundle/config ]; then
  echo ".bundle/config:"
  cat .bundle/config
fi

# Reuse gems directory so that same job does not have to
# spend so much redownloading and reinstalling same gems.
# (Destination directory is created by bundler)
bundle install --local --no-cache --no-prune --clean --path "/mnt/ci-tmp/$JOB_NAME/"

if [ $# -ne 0 ]; then
  echo "--- Starting rspec @ `date` ---"

  bundle exec rake "$@"
fi
