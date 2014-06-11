# encoding: UTF-8

source 'https://rubygems.org'

%w(
  agent_client
  blobstore_client
  bosh_agent
  bosh_aws_cpi
  bosh_common
  bosh-core
  bosh_cpi
  bosh_cli
  bosh_cli_plugin_aws
  bosh_cli_plugin_micro
  bosh_openstack_cpi
  bosh-registry
  bosh_vsphere_cpi
  bosh_warden_cpi
  bosh-director
  bosh-director-core
  bosh-monitor
  bosh-release
  simple_blobstore_server
).each do |gem_name|
  gem gem_name, path: gem_name
end

gem 'rake', '~>10.0'

group :production do
  # this was pulled from bosh_aws_registry's Gemfile.  Why does it exist?
  # also bosh_openstack_registry, director
  gem 'pg'
  gem 'mysql2'
end

group :development do
  gem 'ruby_gntp'
  gem 'git-duet', require: false
end

group :bat do
  gem 'httpclient'
  gem 'json'
  gem 'minitar'
  gem 'net-ssh'
end

group :development, :test do
  gemspec path: 'bosh-dev'
  gemspec path: 'bosh-stemcell'

  gem 'rspec', '3.0.0.beta1'
  gem 'rspec-its'

  gem 'rubocop', require: false
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'ci_reporter'
  gem 'webmock'
  gem 'fakefs'
  # simplecov 0.8.x has an exit code bug: https://github.com/colszowka/simplecov/issues/281
  gem 'simplecov', '~> 0.7.1'
  gem 'codeclimate-test-reporter', require: false
  gem 'vcr'

  # Explicitly do not require serverspec dependency
  # so that it could be monkey patched in a deterministic way
  # in `bosh-stemcell/spec/support/serverspec.rb`
  gem 'specinfra', require: nil

  # for director
  gem 'machinist', '~>1.0'

  # for root level specs
  gem 'rest-client'
  gem 'redis'
  gem 'nats'
  gem 'rugged'

  gem 'sqlite3'
  gem 'timecop'
  gem 'jenkins_api_client'
end
