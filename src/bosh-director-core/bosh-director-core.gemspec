# coding: utf-8
require File.expand_path('../lib/bosh/director/core/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name        = 'bosh-director-core'
  spec.version     = Bosh::Director::Core::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.description = 'BOSH director-core'
  spec.summary     = 'BOSH director-core common code for Director and Microbosh Deployer'

  spec.authors     = ['Cloud Foundry']
  spec.email       = ['support@cloudfoundry.com']
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['lib/**/*'].select { |f| File.file?(f) }
  spec.test_files    = Dir['spec/**/*'].select { |f| File.file?(f) }

  spec.require_paths = ['lib']

  spec.add_dependency 'bosh_common', "~>#{Bosh::Director::Core::VERSION}"
  spec.add_dependency 'bosh-template', "~>#{Bosh::Director::Core::VERSION}"
  spec.add_dependency 'openssl'
  spec.add_dependency 'securerandom'

  spec.add_development_dependency 'fakefs'
  spec.add_development_dependency 'minitar'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
end
