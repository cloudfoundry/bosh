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

  s.add_dependency "bosh_cli", ">=0.19.5"
  s.add_dependency "bosh_common", "~>0.5.0"
  s.add_dependency "bosh_cpi", "~>0.4.4"
  s.add_dependency "bosh_vsphere_cpi", "~>0.4.9"
  s.add_dependency "bosh_aws_cpi", "~>0.6.2"
  s.add_dependency "bosh_aws_registry", "~>0.2.2"
  s.add_dependency "bosh_openstack_cpi", "~>0.0.3"
  s.add_dependency "bosh_openstack_registry", "~>0.0.2"
  s.add_dependency "agent_client", "~>0.1.1"
  s.add_dependency "sqlite3", "~>1.3.3"
end
