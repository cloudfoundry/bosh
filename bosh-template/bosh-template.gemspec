# coding: utf-8
require File.expand_path('lib/bosh/template/version', File.dirname(__FILE__))

Gem::Specification.new do |s|
  s.name         = 'bosh-template'
  s.version      = Bosh::Template::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'Renders bosh templates'
  s.description  = "Renders bosh templates\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'VMware'
  s.homepage = 'https://github.com/cloudfoundry/bosh'
  s.license = 'Apache 2.0'
  s.email        = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.require_path = 'lib'

  s.add_dependency 'semi_semantic', '~>1.1.0'
end
