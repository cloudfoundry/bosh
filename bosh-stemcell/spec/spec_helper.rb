require 'rspec'
require 'fakefs/spec_helpers'

Dir.glob(File.expand_path('support/**/*.rb', File.dirname(__FILE__))).each do |support|
  require support
end
