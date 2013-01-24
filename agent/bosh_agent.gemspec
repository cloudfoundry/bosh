 $:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'agent/version'

Gem::Specification.new do |s|
  s.name = 'bosh_agent'
  s.summary = 'Agent for Cloud Foundry BOSH release engineering tool.'
  s.description = 'This agent listens for instructions from the bosh director on each server that bosh manages.'
  s.author = 'VMware'
  s.version = Bosh::Agent::VERSION
  s.homepage = 'https://github.com/cloudfoundry/bosh'
  s.license = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")

  %w{
    highline
    monit_api
    netaddr
    posix-spawn
    ruby-atmos-pure
    thin
    uuidtools
    yajl-ruby
    blobstore_client
    bosh_common
    bosh_encryption
    }.each { |g| s.add_dependency g }

  s.add_dependency 'sinatra', "~> 1.2.8"
  s.add_dependency 'nats', "~> 0.4.28"
  s.add_dependency 'sigar', ">= 0.7.2"

  s.files = `git ls-files`.split("\n")
  s.executables = %w{agent}
end
