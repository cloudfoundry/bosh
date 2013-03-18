# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name                  = 'bosh_agent'
  s.summary               = 'Agent for Cloud Foundry BOSH release engineering tool.'
  s.description           = 'This agent listens for instructions from the bosh director on each server that bosh manages.'
  s.author                = 'VMware'
  s.version               =  version
  s.homepage              = 'https://github.com/cloudfoundry/bosh'
  s.license               = 'Apache 2.0'
  s.email                 = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.add_dependency 'highline', '~>1.6.2'
  s.add_dependency 'monit_api', "~>#{version}"
  s.add_dependency 'netaddr', "~>1.5.0"
  s.add_dependency 'posix-spawn', "~>0.3.6"
  s.add_dependency 'ruby-atmos-pure', "~>1.0.5"
  s.add_dependency 'thin', "~>1.5.0"
  s.add_dependency 'uuidtools', "~>2.1.3"
  s.add_dependency 'yajl-ruby', "~>1.1.0"
  s.add_dependency 'blobstore_client', "~>#{version}"
  s.add_dependency 'bosh_common', "~>#{version}"
  s.add_dependency 'bosh_encryption', "~>#{version}"
  s.add_dependency 'sinatra', "~>1.2.8"
  s.add_dependency 'nats', "~>0.4.28"
  s.add_dependency 'sigar', ">=0.7.2"
  s.add_dependency "httpclient", "=2.2.4"
  s.add_dependency "sys-filesystem", "~> 1.1.0"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(CHANGELOG)
  s.require_path = "lib"

  s.bindir       = 'bin'
  s.executables  << 'bosh_agent'
end
