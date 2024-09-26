# coding: utf-8
require File.expand_path('../lib/nats_sync/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'bosh-nats-sync'
  spec.version      = NATSSync::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH Nats Sync'
  spec.description  = 'BOSH Nats Sync'
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['README.md', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables << 'bosh-nats-sync'

  spec.add_dependency 'cf-uaa-lib',  '~>3.2.1'
  spec.add_dependency 'logging'
  spec.add_dependency 'openssl'
  spec.add_dependency 'rufus-scheduler'
  spec.add_dependency 'rest-client'
end
