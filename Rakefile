task :default => :spec

Dir.glob('rake/lib/tasks/**/*.rake').each { |r| import r }
require 'ci/reporter/rake/rspec'     # use this if you're using RSpec
