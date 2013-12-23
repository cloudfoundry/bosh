require 'rspec'
require 'rspec/its'
require 'fakefs/spec_helpers'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }
