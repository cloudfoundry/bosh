#!/bin/bash -l
set -e

# BUILD_FLOW_GIT_COMMIT gets set in the bosh_build_flow jenkins jobs. This is used to ensure we check out
# the same git commit for all jenkins jobs in the flow.
if [ -n "$BUILD_FLOW_GIT_COMMIT" ]; then
    git checkout $BUILD_FLOW_GIT_COMMIT
fi

# Cleanup any left over gems and bundler config
rm -rf .bundle tmp

bundle install --without development --local --path tmp/ruby

bundle exec rake $@
