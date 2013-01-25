 $:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'bosh_agent/version'

Gem::Specification.new do |s|
  s.name                  = 'bosh_agent'
  s.summary               = 'Agent for Cloud Foundry BOSH release engineering tool.'
  s.description           = 'This agent listens for instructions from the bosh director on each server that bosh manages.'
  s.author                = 'VMware'
  s.version               = Bosh::Agent::VERSION
  s.homepage              = 'https://github.com/cloudfoundry/bosh'
  s.license               = 'Apache 2.0'
  s.email                 = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.add_dependency 'highline'
  s.add_dependency 'monit_api'
  s.add_dependency 'netaddr'
  s.add_dependency 'posix-spawn'
  s.add_dependency 'ruby-atmos-pure'
  s.add_dependency 'thin'
  s.add_dependency 'uuidtools'
  s.add_dependency 'yajl-ruby'
  s.add_dependency 'blobstore_client'
  s.add_dependency 'bosh_common'
  s.add_dependency 'bosh_encryption'
  s.add_dependency 'sinatra', "~> 1.2.8"
  s.add_dependency 'nats', "~> 0.4.28"
  s.add_dependency 'sigar', ">= 0.7.2"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(CHANGELOG)
  s.require_path = "lib"

  s.bindir       = 'bin'
  s.executables  << 'bosh_agent'
end
