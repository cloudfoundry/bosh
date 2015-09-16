# coding: utf-8
require File.expand_path('../lib/bosh/template/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'bosh-template'
  spec.version      = Bosh::Template::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'Renders bosh templates'
  spec.description  = "Renders bosh templates"
  spec.author       = 'Pivotal'
  spec.email        = 'support@cloudfoundry.com'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'

  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['README.md', 'lib/**/*'].select{ |f| File.file? f }
  spec.test_files   = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables << 'bosh-template'

  spec.add_dependency 'semi_semantic', '~>1.1.0'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
end
