#!/bin/bash -l
set -e
source .rvmrc

gem list | grep bundler > /dev/null || gem install bundler
bundle check || bundle install --without development

if [ -n "$TRACKER_PROJECT_ID" ] && [ -n "$TRACKER_TOKEN" ] ; then
    bundle exec rake $@ && bundle list | grep "tracker-git" > /dev/null && bundle exec tracker --note-delivery
else
    bundle exec rake $@
fi
