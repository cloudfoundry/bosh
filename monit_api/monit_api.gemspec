require File.dirname(__FILE__) + "/lib/monit_api/version"

Gem::Specification.new do |s|
  s.name         = "monit_api"
  s.version      = MonitApi::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh Monit API client"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"

  s.add_dependency "crack"
end
