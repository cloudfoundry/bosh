# coding: utf-8
require File.expand_path('../lib/bosh/monitor/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'bosh-monitor'
  spec.version      = Bosh::Monitor::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH Health Monitor'
  spec.description  = "BOSH Health Monitor"
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['README.md', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables << 'bosh-monitor-console'
  spec.executables << 'bosh-monitor'

  spec.add_dependency 'async'
  spec.add_dependency 'async-http'
  spec.add_dependency 'async-io'
  spec.add_dependency 'logging'
  spec.add_dependency 'nats-pure'
  spec.add_dependency 'net-smtp'
  spec.add_dependency 'openssl'
  spec.add_dependency 'ostruct'
  spec.add_dependency 'puma'
  spec.add_dependency 'sinatra',   '~>2.2.0'
  spec.add_dependency 'dogapi',    '~> 1.45.0'
  spec.add_dependency 'riemann-client'
  spec.add_dependency 'cf-uaa-lib'

  spec.add_development_dependency 'async-rspec'
  spec.add_development_dependency 'timecop'
end
