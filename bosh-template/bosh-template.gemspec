# coding: utf-8
require File.expand_path('../lib/bosh/template/version', __FILE__)

Gem::Specification.new do |s|
  s.name         = 'bosh-template'
  s.version      = Bosh::Template::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'Renders bosh templates'
  s.description  = "Renders bosh templates\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'Pivotal'
  s.email        = 'support@cloudfoundry.com'
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'

  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README.md)
  s.test_files   = s.files.grep(%r{^(test|spec|features)/})
  s.require_path = 'lib'

  s.add_dependency 'semi_semantic', '~>1.1.0'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-its'

  s.bindir      = 'bin'
  s.executables << 'bosh-template'
end
