require File.expand_path('../../../spec/shared_spec_helper', __FILE__)
require 'fakefs/spec_helpers'

require 'cloud'
require 'cloud/vsphere'

Dir[Pathname(__FILE__).parent.join('support', '**/*.rb')].each { |file| require file }

class VSphereSpecConfig
  attr_accessor :logger, :uuid
end

def by(message)
  if block_given?
    yield
  else
    pending message
  end
end

alias and_by by
