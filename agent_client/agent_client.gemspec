# coding: utf-8
require File.expand_path('../lib/agent_client/version', __FILE__)

Gem::Specification.new do |s|
  s.name         = 'agent_client'
  s.version      = Bosh::Agent::Client::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'BOSH agent client'
  s.description  = "BOSH agent client\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'VMware'
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/*`.split("\n")
  s.require_path = 'lib'
  s.test_files   = s.files.grep(%r{^(test|spec|features)/})
  s.bindir       = 'bin'
  s.executables  << 'agent_client'

  s.add_dependency 'httpclient', '=2.2.4'
  s.add_dependency 'yajl-ruby', '~>1.1.0'

  s.add_development_dependency 'rspec'
end
