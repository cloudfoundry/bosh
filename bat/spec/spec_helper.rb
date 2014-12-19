require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'fakefs/spec_helpers'

SPEC_ROOT = File.expand_path(File.dirname(__FILE__))

RSpec.configure do |config|
  unless ENV['BOSH_OS_BATS'] =~ (/^(true|yes|y|1)$/i)
    puts "!!! EXCLUDING SYSTEM SERVICE SPECS !!!"
    config.filter_run_excluding :type => :os
  end
end
