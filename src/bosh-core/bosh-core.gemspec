# coding: utf-8
require File.expand_path('../lib/bosh/core/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name        = 'bosh-core'
  spec.version     = Bosh::Core::VERSION
  spec.summary     = 'BOSH core'
  spec.description = 'BOSH core provides things BOSH needs to exist'

  spec.authors     = ['Cloud Foundry']
  spec.email       = ['support@cloudfoundry.com']
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['lib/**/*'].select { |f| File.file?(f) }
  spec.test_files    = Dir['spec/**/*'].select { |f| File.file?(f) }

  spec.require_paths = ['lib']

  spec.add_dependency 'openssl'
end
