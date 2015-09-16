# coding: utf-8
require File.expand_path('../lib/agent_client/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'agent_client'
  spec.version      = Bosh::Agent::Client::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH agent client'
  spec.description  = "BOSH agent client"
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.test_files   = spec.files.grep(%r{^(test|spec|features)/})
  spec.bindir       = 'bin'
  spec.executables  << 'agent_client'

  spec.add_dependency 'httpclient', '=2.4.0'
  spec.add_dependency 'yajl-ruby', '~>1.2.0'

  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rspec-instafail'
end
