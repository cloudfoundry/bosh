require File.expand_path('../../spec/shared/spec_helper', __dir__)
require 'nats_sync'
require 'webmock/rspec'

Dir.glob(File.expand_path('support/**/*.rb', __dir__)).each { |f| require(f) }

def asset_path(filename)
  File.expand_path(File.join(File.dirname(__FILE__), 'assets', filename))
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
