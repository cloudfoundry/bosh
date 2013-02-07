# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "bosh_aws_cpi"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH AWS CPI"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- bin/* lib/* scripts/*`.split("\n") + %w(README.md)
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(bosh_aws_console)

  s.add_dependency "aws-sdk", "~>1.8.0"
  s.add_dependency "bosh_common", "~>#{version}"
  s.add_dependency "bosh_cpi", "~>#{version}"
  s.add_dependency "httpclient", "=2.2.4"
  s.add_dependency "uuidtools", "~>2.1.3"
  s.add_dependency "yajl-ruby", ">=0.8.2"
end
