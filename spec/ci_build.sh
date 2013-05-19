#!/bin/bash -l
set -e
source .rvmrc

gem list | grep bundler > /dev/null || gem install bundler

# bundle update all bosh gems so the Gemfile.lock will be updated with the most recent CANDIDATE_BUILD_NUMBER
# Assumption that all the bosh gems start with bosh_ or are dependencies of gems that start with bosh_
bundle list | awk '{print $2}' | grep ^bosh_ | xargs bundle update

bundle check || bundle install --without development

if [ -n "$TRACKER_PROJECT_ID" ] && [ -n "$TRACKER_TOKEN" ] ; then
    bundle exec rake $@ && bundle list | grep "tracker-git" > /dev/null && bundle exec tracker --note-delivery
else
    bundle exec rake $@
fi
