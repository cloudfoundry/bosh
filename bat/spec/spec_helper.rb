require 'rspec'
require 'rspec/its'
require 'fakefs/spec_helpers'

SPEC_ROOT = File.expand_path(File.dirname(__FILE__))

Dir.glob(File.expand_path('support/**/*.rb', SPEC_ROOT)).each { |f| require(f) }
