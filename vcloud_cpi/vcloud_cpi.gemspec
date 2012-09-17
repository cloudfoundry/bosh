require File.dirname(__FILE__) + "/lib/cloud/vcloud/version"

Gem::Specification.new do |s|
  s.name         = "bosh_vcloud_cpi"
  s.version      = Bosh::Clouds::VCloud::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH vCloud CPI"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"

  s.add_dependency "bosh_common"
  s.add_dependency "bosh_cpi", ">= 0.4.2"
  s.add_dependency "ruby_vcloud_sdk"
  s.add_dependency "uuidtools"
  s.add_dependency "yajl-ruby", ">=0.8.2"
end
