# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "director"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH Director"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage      = 'https://github.com/cloudfoundry/bosh'
  s.license       = 'Apache 2.0'
  s.email         = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")



  s.files        = `git ls-files -- lib/* db/*`.split("\n") + %w(CHANGELOG)
  s.require_path = "lib"

  s.add_dependency  "bcrypt-ruby", "~>3.0.1"
  s.add_dependency  "blobstore_client", "~>#{version}"
  s.add_dependency  "bosh_common", "~>#{version}"
  s.add_dependency  "bosh_encryption", "~>#{version}"
  s.add_dependency  "bosh_cpi", "~>#{version}"
  s.add_dependency  "bosh_openstack_cpi", "~>#{version}"
  s.add_dependency  "bosh_aws_cpi", "~>#{version}"
  s.add_dependency  "bosh_vcloud_cpi", "~>#{version}"
  s.add_dependency  "bosh_vsphere_cpi", "~>#{version}"
  s.add_dependency  "eventmachine", "~>0.12.9"
  s.add_dependency  "fog", "~> 1.11.1"
  s.add_dependency  "httpclient", "=2.2.4"
  s.add_dependency  "nats", "~> 0.4.28"
  s.add_dependency  "netaddr", "~>1.5.0"
  s.add_dependency  "rack-test","~>0.6.2"         # needed for console
  s.add_dependency  "rake", "~>10.0.3"
  s.add_dependency  "redis", "~>3.0.2"
  s.add_dependency  "resque", "~>1.23.0"
  s.add_dependency  "rufus-scheduler", "~> 2.0.18"
  s.add_dependency  "sequel", "~>3.46.0"
  s.add_dependency  "sinatra", "~>1.4.2"
  s.add_dependency  'sys-filesystem', "~> 1.1.0"
  s.add_dependency  "thin", "~>1.5.0"
  s.add_dependency  "yajl-ruby", "~>1.1.0"

  s.bindir      = 'bin'
  s.executables << 'director_console'
  s.executables << 'director_scheduler'
  s.executables << 'director'
  s.executables << 'drain_workers'
  s.executables << 'worker'
  s.executables << 'migrate'
end
