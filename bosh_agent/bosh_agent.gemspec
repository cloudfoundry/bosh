# coding: utf-8
require File.expand_path('../lib/bosh_agent/version', __FILE__)
version = Bosh::Agent::VERSION

Gem::Specification.new do |s|
  s.name        = 'bosh_agent'
  s.version     =  version
  s.summary     = 'Agent for Cloud Foundry BOSH release engineering tool.'
  s.description = "This agent listens for instructions from the bosh director on each server that bosh manages.\n#{`git rev-parse HEAD`[0, 6]}"
  s.author      = 'VMware'
  s.homepage    = 'https://github.com/cloudfoundry/bosh'
  s.license     = 'Apache 2.0'
  s.email       = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  # Third party dependencies
  s.add_dependency 'netaddr',         '~>1.5.0'
  s.add_dependency 'thin',            '~>1.5.0'
  s.add_dependency 'yajl-ruby',       '~>1.1.0'
  s.add_dependency 'sinatra',         '~>1.4.2'
  s.add_dependency 'nats',            '~>0.4.28'
  s.add_dependency 'sigar',           '~>0.7.2'
  s.add_dependency 'httpclient',      '=2.2.4'
  s.add_dependency 'syslog_protocol', '~>0.9.2'
  s.add_dependency 'crack',           '~>0.3.2'

  # Bosh Dependencies
  s.add_dependency 'bosh-core',        "~>#{version}"
  s.add_dependency 'bosh_common',      "~>#{version}"
  s.add_dependency 'blobstore_client', "~>#{version}"

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'fakefs'

  s.files         = `git ls-files -- lib/*`.split("\n") + %w(CHANGELOG)
  s.require_paths = %w(lib)
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.bindir        = 'bin'
  s.executables   << 'bosh_agent'
end
