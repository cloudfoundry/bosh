# encoding: UTF-8

source 'https://rubygems.org'

gemspec path: 'agent_client'
gemspec path: 'blobstore_client'
gemspec path: 'bosh_agent'
gemspec path: 'bosh_aws_cpi'
gemspec path: 'bosh_common'
gemspec path: 'bosh-core'
gemspec path: 'bosh_cpi'
gemspec path: 'bosh_cli'
gemspec path: 'bosh_cli_plugin_aws'
gemspec path: 'bosh_cli_plugin_micro'
gemspec path: 'bosh_openstack_cpi'
gemspec path: 'bosh-registry'
gemspec path: 'bosh_vsphere_cpi'
gemspec path: 'bosh-director'
gemspec path: 'bosh-monitor'
gemspec path: 'bosh-release'
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

  gem 'rubocop', require: false
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'ci_reporter'
  gem 'rspec'
  gem 'rspec-fire'
  gem 'rspec-instafail'
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
