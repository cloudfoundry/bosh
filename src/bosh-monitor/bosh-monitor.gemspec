# coding: utf-8
require File.expand_path('../lib/bosh/monitor/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'bosh-monitor'
  spec.version      = Bosh::Monitor::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH Health Monitor'
  spec.description  = 'BOSH Health Monitor'

  spec.authors     = ['Cloud Foundry']
  spec.email       = ['support@cloudfoundry.com']
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['lib/**/*'].select { |f| File.file?(f) }
  spec.test_files    = Dir['spec/**/*'].select { |f| File.file?(f) }

  spec.bindir        = 'bin'
  spec.executables   = ['bosh-monitor', 'bosh-monitor-console']
  spec.require_paths = ['lib']

  spec.add_dependency 'async'
  spec.add_dependency 'async-http'
  spec.add_dependency 'async-io'
  spec.add_dependency 'cf-uaa-lib'
  spec.add_dependency 'logging'
  spec.add_dependency 'nats-pure'
  spec.add_dependency 'openssl'
  spec.add_dependency 'ostruct'
  spec.add_dependency 'puma'
  spec.add_dependency 'securerandom'
  spec.add_dependency 'sinatra'

  spec.add_dependency 'dogapi'
  spec.add_dependency 'net-smtp'
  spec.add_dependency 'riemann-client'

  spec.add_development_dependency 'async-rspec'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'webmock'
end
