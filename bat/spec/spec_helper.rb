require 'rspec'

require 'fakefs/spec_helpers'

SPEC_ROOT = File.expand_path(File.dirname(__FILE__))

Dir.glob(File.expand_path('support/**/*.rb', File.dirname(__FILE__))).each do |support|
  require support
end
