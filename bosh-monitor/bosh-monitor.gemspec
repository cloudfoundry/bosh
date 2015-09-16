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
  spec.executables << 'listener'

  spec.add_dependency 'eventmachine',    '~>1.0.0'
  spec.add_dependency 'logging',         '~>1.8.2'
  spec.add_dependency 'em-http-request', '~>0.3.0'
  spec.add_dependency 'nats',      '=0.5.0.beta.12'
  spec.add_dependency 'yajl-ruby', '~>1.2.0'
  spec.add_dependency 'thin',      '~>1.5.0'
  spec.add_dependency 'sinatra',   '~>1.4.2'
  spec.add_dependency 'aws-sdk',   '1.60.2'
  spec.add_dependency 'dogapi',    '~> 1.6.0'
  spec.add_dependency 'cf-uaa-lib',  '~>3.2.1'
  spec.add_dependency 'httpclient',  '=2.4.0'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
end
