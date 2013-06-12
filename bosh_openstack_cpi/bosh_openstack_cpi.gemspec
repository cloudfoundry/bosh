# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "bosh_openstack_cpi"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH OpenStack CPI"
  s.description  = "BOSH OpenStack CPI\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = "Piston Cloud Computing / VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- bin/* lib/*`.split("\n") + %w(README.md USAGE.md)
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(bosh_openstack_console)

  s.add_dependency "fog", "~>1.12.1"
  s.add_dependency "bosh_common", "~>#{version}"
  s.add_dependency "bosh_cpi", "~>#{version}"
  s.add_dependency "bosh_registry", "~>#{version}"
  s.add_dependency "httpclient", "=2.2.4"
  s.add_dependency "yajl-ruby", ">=0.8.2"
end
