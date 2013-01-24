require File.dirname(__FILE__) + "/lib/deployer/version"

Gem::Specification.new do |s|
  s.name         = "bosh_deployer"
  s.version      = Bosh::Deployer::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Micro BOSH Deployer"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- lib/* config/*`.split("\n") + %w(README.rdoc Rakefile)
  s.require_paths = ["lib", "config"]

  s.add_dependency "bosh_cli"
  s.add_dependency "bosh_cpi"
  s.add_dependency "bosh_vcloud_cpi"
  s.add_dependency "bosh_vsphere_cpi"
  s.add_dependency "bosh_aws_cpi"
  s.add_dependency "bosh_aws_registry"
  s.add_dependency "bosh_openstack_cpi"
  s.add_dependency "bosh_openstack_registry"
  s.add_dependency "agent_client"
  s.add_dependency "sqlite3", "~>1.3.3"
end
