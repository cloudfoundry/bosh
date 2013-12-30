# coding: utf-8
require File.expand_path('../lib/bosh/release/version', __FILE__)

version = Bosh::Release::VERSION

Gem::Specification.new do |s|
  s.name         = 'bosh-release'
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'Bosh package compiler'
  s.description  = "Bosh package compiler\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'VMware'
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables  = %w(bosh-release)

  s.add_dependency 'agent_client',     "~>#{version}"
  s.add_dependency 'blobstore_client', "~>#{version}"
  s.add_dependency 'bosh_common',      "~>#{version}"
  s.add_dependency 'yajl-ruby', '~>1.1.0'
  s.add_dependency 'trollop',   '~>1.16'
end
