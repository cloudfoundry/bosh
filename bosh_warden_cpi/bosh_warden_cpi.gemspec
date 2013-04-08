require File.dirname(__FILE__) + "/lib/cloud/warden/version"

Gem::Specification.new do |s|
  s.name         = "bosh_warden_cpi"
  s.version      = Bosh::Clouds::Warden::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH Warden CPI"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"

  s.add_dependency "bosh_common"
  s.add_dependency "bosh_cpi"
  s.add_dependency "warden-protocol"
  s.add_dependency "warden-client"
  s.add_dependency "sequel"
  s.add_dependency "yajl-ruby"
end
