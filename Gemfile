# encoding: UTF-8

source 'https://rubygems.org'

gem 'agent_client', path: 'agent_client'
gem 'blobstore_client', path: 'blobstore_client'
gem 'bosh_common', path: 'bosh_common'
gem 'bosh-core', path: 'bosh-core'
gem 'bosh_cpi', path: 'bosh_cpi'
gem 'bosh_cli', path: 'bosh_cli'
gem 'bosh_cli_plugin_aws', path: 'bosh_cli_plugin_aws'
gem 'bosh_cli_plugin_micro', path: 'bosh_cli_plugin_micro'
gem 'bosh-registry', path: 'bosh-registry'
gem 'bosh-director', path: 'bosh-director'
gem 'bosh-director-core', path: 'bosh-director-core'
gem 'bosh-monitor', path: 'bosh-monitor'
gem 'bosh-release', path: 'bosh-release'
gem 'bosh-template', path: 'bosh-template'
gem 'simple_blobstore_server', path: 'simple_blobstore_server'

gem 'bosh_aws_cpi', '~>2.1'
gem 'rake', '~>10.0'

# json version is hardcoded in release director, health_monitor and registry packages
# when modified needs to be updated there as well
gem 'json', '=1.8.3'

group :production do
  # this was pulled from bosh_aws_registry's Gemfile.  Why does it exist?
  # also bosh_openstack_registry, director
  gem 'pg'
  gem 'mysql2'
end

group :bat do
  gem 'httpclient'
  gem 'minitar'
  gem 'net-ssh'
end

group :development, :test do
  gem 'bosh-dev', path: 'bosh-dev'
  gem 'bosh-stemcell', path: 'bosh-stemcell'
  gem 'serverspec', '0.15.4'

  gem 'rspec', '~> 3.0.0'
  gem 'rspec-its'
  gem 'rspec-instafail'

  gem 'rubocop', require: false
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'webmock'
  gem 'fakefs'
  gem 'simplecov', '~> 0.9.0'
  gem 'sinatra'
  gem 'sinatra-contrib'
  gem 'codeclimate-test-reporter', require: false
  gem 'vcr'
  gem 'pry'

  # avoid upgrading until this issue is resolved: https://github.com/eventmachine/eventmachine/issues/633
  gem 'eventmachine', '1.0.3'

  # Explicitly do not require serverspec dependency
  # so that it could be monkey patched in a deterministic way
  # in `bosh-stemcell/spec/support/serverspec_monkeypatch.rb`
  gem 'specinfra', '1.15.0', require: nil

  # for director
  gem 'machinist', '~>1.0'

  # for root level specs
  gem 'rest-client'
  gem 'redis'
  gem 'nats'
  gem 'rugged'

  gem 'sqlite3'
  gem 'timecop', '~>0.7.1'
  gem 'blue-shell'
end
