# coding: utf-8
require File.expand_path('../lib/nats_sync/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'bosh-nats-sync'
  spec.version      = NATSSync::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH Nats Sync'
  spec.description  = 'BOSH Nats Sync'

  spec.authors     = ['Cloud Foundry']
  spec.email       = ['support@cloudfoundry.com']
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['lib/**/*'].select { |f| File.file?(f) }
  spec.test_files    = Dir['spec/**/*'].select { |f| File.file?(f) }

  spec.bindir        = 'bin'
  spec.executables   = ['bosh-nats-sync']
  spec.require_paths = ['lib']

  spec.add_dependency 'cf-uaa-lib'
  spec.add_dependency 'json'
  spec.add_dependency 'logging'
  spec.add_dependency 'openssl'
  spec.add_dependency 'rufus-scheduler'
  spec.add_dependency 'rest-client'
end
