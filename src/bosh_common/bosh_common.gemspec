# coding: utf-8
require File.expand_path('../lib/common/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'bosh_common'
  spec.version      = Bosh::Common::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH common'
  spec.description  = 'BOSH common'

  spec.authors     = ['Cloud Foundry']
  spec.email       = ['support@cloudfoundry.com']
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['lib/**/*'].select { |f| File.file?(f) }
  spec.test_files    = Dir['spec/**/*'].select { |f| File.file?(f) }

  spec.require_paths = ['lib']

  spec.add_dependency 'semi_semantic'
  spec.add_dependency 'logging'
  spec.add_dependency 'openssl'

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
end
