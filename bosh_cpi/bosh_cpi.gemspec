# coding: utf-8
require File.expand_path('../lib/cloud/version', __FILE__)

version = Bosh::Clouds::VERSION

Gem::Specification.new do |spec|
  spec.name        = 'bosh_cpi'
  spec.version     = version
  spec.platform    = Gem::Platform::RUBY
  spec.summary     = 'BOSH CPI'
  spec.description = "BOSH CPI"
  spec.author      = 'VMware'
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache 2.0'
  spec.email       = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'

  spec.add_dependency 'bosh_common', "~>#{version}"
  spec.add_dependency 'membrane',    '~>1.1.0'
  spec.add_dependency 'logging',     '~>1.8.2'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
end
