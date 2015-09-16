# coding: utf-8
require File.expand_path('../lib/bosh/registry/version', __FILE__)

version = Bosh::Registry::VERSION

Gem::Specification.new do |spec|
  spec.name         = 'bosh-registry'
  spec.version      = Bosh::Registry::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH Registry'
  spec.description  = "BOSH Registry"
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['README.md', 'db/**/*', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables  = %w(bosh-registry bosh-registry-migrate)

  spec.add_dependency 'sequel',    '~>3.43.0'
  spec.add_dependency 'sinatra',   '~>1.4.2'
  spec.add_dependency 'thin',      '~>1.5.0'
  spec.add_dependency 'yajl-ruby', '~>1.2.0'
  spec.add_dependency 'fog-aws',   '<=0.1.1'
  spec.add_dependency 'fog',       '~>1.31.0'
  spec.add_dependency 'aws-sdk',   '1.60.2'
  spec.add_dependency 'bosh_cpi', "~>#{version}"

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'mono_logger'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'httpclient'
end
