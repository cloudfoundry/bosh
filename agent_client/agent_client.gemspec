require File.dirname(__FILE__) + "/lib/agent_client/version"

Gem::Specification.new do |s|
  s.name         = "agent_client"
  s.version      = Bosh::Agent::Client::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH agent client"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage = 'https://github.com/cloudfoundry/bosh'
  s.license = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")


  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.require_path = "lib"

  s.add_dependency "httpclient"
  s.add_dependency "yajl-ruby"
end
