# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "bosh_deployer"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Micro BOSH Deployer"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files         = `git ls-files -- lib/* config/*`.split("\n") + %w(README.rdoc)
  s.require_paths = ["lib", "config"]

  s.add_dependency "bosh_cli", "~>#{version}"
  s.add_dependency "bosh_cpi", "~>#{version}"
  s.add_dependency "bosh_vcloud_cpi", "~>#{version}"
  s.add_dependency "bosh_vsphere_cpi", "~>#{version}"
  s.add_dependency "bosh_aws_cpi", "~>#{version}"
  s.add_dependency "bosh_aws_registry", "~>#{version}"
  s.add_dependency "bosh_openstack_cpi", "~>#{version}"
  s.add_dependency "bosh_openstack_registry", "~>#{version}"
  s.add_dependency "agent_client", "~>#{version}"
  s.add_dependency "sqlite3", "~>1.3.7"
end
