# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "health_monitor"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH Health Montior"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.require_path = "lib"

  s.add_dependency "eventmachine", "~>0.12.10"
  s.add_dependency "logging", "~>1.5.0"
  s.add_dependency "em-http-request", "~>0.3.0"
  s.add_dependency "nats", "~>0.4.28"
  s.add_dependency "yajl-ruby", "~>1.1.0"
  s.add_dependency "thin", "~>1.5.0"
  s.add_dependency "sinatra", "~>1.4.2"
  s.add_dependency "aws-sdk", "1.8.5"

  s.bindir      = 'bin'
  s.executables << 'console'
  s.executables << 'health_monitor'
  s.executables << 'listener'
end
