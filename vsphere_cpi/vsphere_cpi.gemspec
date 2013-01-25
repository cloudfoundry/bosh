require File.dirname(__FILE__) + "/lib/cloud/vsphere/version"

Gem::Specification.new do |s|
  s.name         = "bosh_vsphere_cpi"
  s.version      = Bosh::Clouds::VSphere::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH VSphere CPI"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- db/* lib/*`.split("\n") + %w(README)
  s.require_path = "lib"

  s.add_dependency "bosh_common"
  s.add_dependency "bosh_cpi"
  s.add_dependency "membrane"
  s.add_dependency "ruby_vim_sdk"
  s.add_dependency "sequel"
  s.add_dependency "uuidtools"
end
