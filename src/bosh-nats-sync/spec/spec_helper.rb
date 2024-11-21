SPEC_ROOT = File.expand_path(File.dirname(__FILE__))

require File.join(SPEC_ROOT, '../../spec/shared/spec_helper')

require 'nats_sync'
require 'webmock/rspec'
require 'tempfile'

Dir.glob(File.join(SPEC_ROOT, 'support/**/*.rb')).each { |f| require(f) }

def asset_path(filename)
  File.join(SPEC_ROOT, 'assets', filename)
end

def sample_config
  asset_path('sample_config.yml')
end

def sample_hm_subject
  asset_path('hm-subject')
end

def sample_director_subject
  asset_path('director-subject')
end
