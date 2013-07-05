# encoding: UTF-8

source 'https://rubygems.org'

ruby '1.9.3'

gemspec path: 'agent_client'
gemspec path: 'blobstore_client'
gemspec path: 'bosh_agent'
gemspec path: 'bosh_aws_cpi'
gemspec path: 'bosh_common'
gemspec path: 'bosh_cpi'
gemspec path: 'bosh_cli'
gemspec path: 'bosh_cli_plugin_aws'
gemspec path: 'bosh_cli_plugin_micro'
gemspec path: 'bosh_encryption'
gemspec path: 'bosh_openstack_cpi'
gemspec path: 'bosh_registry'
gemspec path: 'bosh_vsphere_cpi'
gemspec path: 'director'
gemspec path: 'health_monitor'
gemspec path: 'monit_api'
gemspec path: 'package_compiler'
gemspec path: 'ruby_vim_sdk'
gemspec path: 'simple_blobstore_server'

gem 'rake', '~>10.0'

group :production do
  # this was pulled from bosh_aws_registry's Gemfile.  Why does it exist?
  # also bosh_openstack_registry, director
  gem 'pg'
  gem 'mysql2'
end

group :development do
  gem 'ruby_gntp'
  gem 'debugger' if RUBY_VERSION < '2.0.0'
end

group :bat do
  gem 'httpclient'
  gem 'json'
  gem 'minitar'
  gem 'net-ssh'
end

group :development, :test do
  gemspec path: 'bosh-dev'

  gem 'rubocop', require: false
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-rspec'
  gem 'ci_reporter'
  gem 'rspec'
  gem 'rspec-fire'
  gem 'webmock'
  gem 'fakefs'
  gem 'simplecov'
  gem 'simplecov-rcov'

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
