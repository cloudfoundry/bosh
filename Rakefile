# encoding: UTF-8

task default: :spec

Dir.glob('bosh-dev/lib/tasks/**/*.rake').each { |r| import r }
require 'ci/reporter/rake/rspec'     # use this if you're using RSpec
