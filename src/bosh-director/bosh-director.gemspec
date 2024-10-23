# coding: utf-8
require File.expand_path('../lib/bosh/director/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'bosh-director'
  spec.version      = Bosh::Director::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH Director'
  spec.description  = 'BOSH Director'

  spec.authors     = ['Cloud Foundry']
  spec.email       = ['support@cloudfoundry.com']
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['db/**/*', 'lib/**/*'].select { |f| File.file?(f) }
  spec.test_files    = Dir['spec/**/*'].select { |f| File.file?(f) }

  spec.bindir        = 'bin'
  spec.executables   = [
    'bosh-director',
    'bosh-director-console',
    'bosh-director-drain-workers',
    'bosh-director-metrics-server',
    'bosh-director-migrate',
    'bosh-director-scheduler',
    'bosh-director-sync-dns',
    'bosh-director-trigger-one-time-sync-dns',
    'bosh-director-worker',
  ]
  spec.require_paths = ['lib']

  # NOTE: We must specify all transitive BOSH gem dependencies found in the
  # external CPIs, in order to ensure appropriate versions are installed.
  # Also do the same in bosh_cli_plugin_micro.gemspec
  # Review this once CPIs are completely externalized and "micro" goes away.
  spec.add_dependency 'bosh_common',   "~>#{Bosh::Director::VERSION}"
  spec.add_dependency 'bosh-template', "~>#{Bosh::Director::VERSION}"

  spec.add_dependency 'bcrypt'
  spec.add_dependency 'bosh_cpi'
  spec.add_dependency 'cf-uaa-lib'
  spec.add_dependency 'json'
  spec.add_dependency 'logging'
  spec.add_dependency 'membrane'
  spec.add_dependency 'nats-pure'
  spec.add_dependency 'openssl'
  spec.add_dependency 'ostruct'
  spec.add_dependency 'prometheus-client'
  spec.add_dependency 'puma'
  spec.add_dependency 'rack-test'
  spec.add_dependency 'rake'
  spec.add_dependency 'rufus-scheduler'
  spec.add_dependency 'securerandom'
  spec.add_dependency 'sequel'
  spec.add_dependency 'sinatra'
  spec.add_dependency 'sinatra-contrib'
  spec.add_dependency 'sys-filesystem'
  spec.add_dependency 'talentbox-delayed_job_sequel'
  spec.add_dependency 'tzinfo-data'
  spec.add_dependency 'unix-crypt'

  spec.add_development_dependency 'bosh-dev'
  spec.add_development_dependency 'fakefs'
  spec.add_development_dependency 'factory_bot'
  spec.add_development_dependency 'minitar'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'webmock'
end
