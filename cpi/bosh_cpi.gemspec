require File.dirname(__FILE__) + "/lib/cloud/version"

Gem::Specification.new do |s|
  s.name         = "bosh_cpi"
  s.version      = Bosh::Clouds::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH CPI"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"

  s.add_dependency "bosh_common", "~>0.5"
end
