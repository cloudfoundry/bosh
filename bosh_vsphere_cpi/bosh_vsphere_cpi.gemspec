# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "bosh_vsphere_cpi"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH VSphere CPI"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- db/* lib/*`.split("\n") + %w(README)
  s.require_path = "lib"
  s.bindir       = 'bin'

  s.executables = 'vsphere_cpi_console'

  s.add_dependency "bosh_common", "~>#{version}"
  s.add_dependency "bosh_cpi", "~>#{version}"
  s.add_dependency "membrane", "~>0.0.2"
  s.add_dependency "ruby_vim_sdk", "~>#{version}"
  s.add_dependency "sequel", "~>3.46.0"
end
