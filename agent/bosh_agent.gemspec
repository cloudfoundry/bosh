 $:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'agent/version'

Gem::Specification.new do |s|
  s.name = 'bosh_agent'
  s.summary = 'Agent for Cloud Foundry BOSH release engineering tool.'
  s.description = 'This agent listens for instructions from the bosh director on each server that bosh manages.'
  s.author = 'VMware'
  s.homepage = 'https://github.com/cloudfoundry/bosh'
  s.license = 'Apache 2.0'
  s.version = Bosh::Agent::VERSION

  %w{
    highline
    monit_api
    netaddr
    posix-spawn
    rack-test
    rake
    ruby-atmos-pure
    sinatra
    thin
    uuidtools
    yajl-ruby
    }.each { |g| s.add_dependency g }

  %w{
    blobstore_client ~> 0.3.13
    bosh_common >= 0.5.1
    bosh_encryption >= 0.0.3
    nats = 0.4.22
    sigar >= 0.7.2
    }.each_slice(3) { |g,o,v| s.add_dependency(g, "#{o} #{v}") }

  %w{
    ci_reporter
    guard
    guard-bundler
    guard-rspec
    rcov
    ruby-debug
    ruby-debug19
    ruby_gntp
    simplecov
    simplecov-rcov
    }.each { |g| s.add_development_dependency g }

  %w{
    rspec = 2.8
    }.each_slice(3) { |g,o,v| s.add_development_dependency(g, "#{o} #{v}") }

  s.files = `git ls-files`.split("\n")
  s.executables = %w{agent}
end
