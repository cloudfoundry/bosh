# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name          = "bosh_aws_bootstrap"
  s.version       = version
  s.platform      = Gem::Platform::RUBY
  s.description   = %q{BOSH plugin to easily create and delete an AWS VPC}
  s.summary       = %q{BOSH plugin to easily create and delete an AWS VPC}
  s.author        = "VMware"
  s.homepage      = 'https://github.com/cloudfoundry/bosh'
  s.license       = 'Apache 2.0'
  s.email         = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files         = `git ls-files -- lib/* templates/*`.split($/)
  s.require_path = "lib"

  s.add_dependency "bosh_cli", "~>#{version}"
  s.add_dependency "bosh_aws_cpi", "~>#{version}"
  s.add_dependency "uuidtools", "~>2.1.3"
end
