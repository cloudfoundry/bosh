require File.expand_path('../../spec/shared/spec_helper', __dir__)
require 'nats_sync'
require 'webmock/rspec'
require_relative 'support/uaa_helpers'

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), 'assets', filename))
end

def sample_config
  spec_asset('sample_config.yml')
end

def sample_hm_subject
  spec_asset('hm-subject')
end

def sample_director_subject
  spec_asset('director-subject')
end
