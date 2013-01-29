# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "bosh_openstack_registry"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH OpenStack registry"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- bin/* lib/*`.split("\n") +
                   %w(README.md)
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(openstack_registry)

  s.add_dependency "sequel", "~>3.43.0"
  s.add_dependency "sinatra", "~> 1.2.8"
  s.add_dependency "thin", "~>1.5.0"
  s.add_dependency "yajl-ruby", "~>1.1.0"
  s.add_dependency "fog", "~>1.9.0"
end
