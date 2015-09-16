# coding: utf-8
require File.expand_path('../lib/bosh/release/version', __FILE__)

version = Bosh::Release::VERSION

Gem::Specification.new do |spec|
  spec.name         = 'bosh-release'
  spec.version      = version
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'Bosh package compiler'
  spec.description  = "Bosh package compiler"
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables  = %w(bosh-release)

  spec.add_dependency 'agent_client',     "~>#{version}"
  spec.add_dependency 'blobstore_client', "~>#{version}"
  spec.add_dependency 'bosh_common',      "~>#{version}"
  spec.add_dependency 'bosh-template',    "~>#{version}"
  spec.add_dependency 'yajl-ruby', '~>1.2.0'
  spec.add_dependency 'trollop',   '~>1.16'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
end
