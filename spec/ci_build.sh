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

bundle install --without development --local --path tmp/

bundle exec rake --trace ci:setup:rspec "$@"
