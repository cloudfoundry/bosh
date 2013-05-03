task :default => :spec

Dir.glob('rake/**/*.rake').each { |r| import r }
require 'ci/reporter/rake/rspec'     # use this if you're using RSpec
require_relative 'rake/helpers/rake_helpers'

