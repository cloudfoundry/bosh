require File.dirname(__FILE__) + "/lib/agent_client/version"

Gem::Specification.new do |s|
  s.name         = "agent_client"
  s.version      = Bosh::Agent::Client::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH agent client"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"

  s.add_dependency "httpclient"
  s.add_dependency "yajl-ruby"
end
