# coding: utf-8
require File.expand_path('../lib/bosh/dev/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = 'bosh-dev'
  spec.version       = Bosh::Dev::VERSION
  spec.summary       = 'BOSH dev'
  spec.description   = 'BOSH dev - utilities for BOSH development'

  spec.authors     = ['Cloud Foundry']
  spec.email       = ['support@cloudfoundry.com']
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['lib/**/*'].select { |f| File.file?(f) }
  spec.test_files    = Dir['spec/**/*'].select { |f| File.file?(f) }

  spec.require_paths = ['lib']

  spec.add_dependency 'bosh_common'
  spec.add_dependency 'bosh-core'
  spec.add_dependency 'bosh-director'
  spec.add_dependency 'bundler'
  spec.add_dependency 'logging'
  spec.add_dependency 'json'
  spec.add_dependency 'openssl'

  spec.add_development_dependency 'fakefs'
end
