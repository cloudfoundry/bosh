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

  spec.add_dependency 'eventmachine',    '~>1.2.0'
  spec.add_dependency 'logging',         '~>2.2.2'
  spec.add_dependency 'em-http-request', '~>0.3.0'
  spec.add_dependency 'nats',      '~>0.8'
  spec.add_dependency 'thin',      '~>1.7.0'
  spec.add_dependency 'sinatra',   '~>1.4.2'
  spec.add_dependency 'dogapi',    '~> 1.21.0'
  spec.add_dependency 'riemann-client', '~>0.2.6'
  spec.add_dependency 'cf-uaa-lib',  '~>3.2.1'
  spec.add_dependency 'httpclient',  '~>2.8.3'
end
