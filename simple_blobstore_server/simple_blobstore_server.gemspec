# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "simple_blobstore_server"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH Simple Blobstore Server"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.require_path = "lib"

  s.add_dependency "thin", "~>1.5.0"
  s.add_dependency "sinatra", "~> 1.4.2"

  s.bindir      = 'bin'
  s.executables << 'simple_blobstore_server'
end
