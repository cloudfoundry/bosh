#!/bin/bash -l
set -e

# BUILD_FLOW_GIT_COMMIT gets set in the bosh_build_flow jenkins jobs. This is used to ensure we check out
# the same git commit for all jenkins jobs in the flow.
if [ -n "$BUILD_FLOW_GIT_COMMIT" ]; then
    git checkout $BUILD_FLOW_GIT_COMMIT
fi

source .rvmrc

gem list | grep bundler > /dev/null || gem install bundler

# prune old gems
yes n | gem cleanup

# bundle update all bosh gems so the Gemfile.lock will be updated with the most recent CANDIDATE_BUILD_NUMBER
find . -name *.gemspec | cut -d '/' -f2 | xargs bundle update

bundle check || bundle install --without development

if [ -n "$TRACKER_PROJECT_ID" ] && [ -n "$TRACKER_TOKEN" ] ; then
    bundle exec rake $@ && bundle list | grep "tracker-git" > /dev/null && bundle exec tracker --note-delivery
else
    bundle exec rake $@
fi
