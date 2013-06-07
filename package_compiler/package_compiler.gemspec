# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "package_compiler"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh package compiler"
  s.description  = "Bosh package compiler\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(package_compiler)

  s.add_dependency "agent_client", "~>#{version}"
  s.add_dependency "blobstore_client", "~>#{version}"
  s.add_dependency "bosh_common", "~>#{version}"
  s.add_dependency "yajl-ruby", "~>1.1.0"
  s.add_dependency "trollop", "~>1.16"
end
