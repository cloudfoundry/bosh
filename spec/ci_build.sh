#!/bin/bash -l
set -e

env | sort                      # so we know what variables are present.

git clean -df && git checkout . # ensure that any modifications or stray files are removed
rm -rf .bundle                  # Cleanup any left over gems and bundler config

# BUILD_FLOW_GIT_COMMIT gets set in the bosh_build_flow jenkins jobs.
# This ensures we check out the same git commit for all jenkins jobs in the flow.
if [ -n "$BUILD_FLOW_GIT_COMMIT" ]; then
    git checkout $BUILD_FLOW_GIT_COMMIT
fi

echo "--- Starting bundle install @ `date` ---"

# Reuse gems directory so that same job does not have to
# spend so much redownloading and reinstalling same gems.
# (Destination directory is created by bundler)
bundle install --local --clean --path /tmp/$JOB_NAME/

echo "--- Starting rspec @ `date` ---"

bundle exec rake --trace ci:setup:rspec "$@"
