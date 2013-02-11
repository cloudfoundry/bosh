#!/usr/bin/env ruby

system("bundle") unless ENV['TRAVIS'] # special bundle configuration for travis, done automatically

# run both suites unless one is explicitly specified
system("bundle exec rake spec:integration") || raise("failed to run spec/integration") unless ENV['SUITE'] == 'unit'
system("bundle exec rake spec:unit") || raise("failed to run unit tests") unless ENV['SUITE'] == 'integration'
