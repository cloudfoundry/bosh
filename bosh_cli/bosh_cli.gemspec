# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2012 VMware, Inc.
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "bosh_cli"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH CLI"
  s.description  = "BOSH command-line tool for release engineering and deployment"
  s.author       = "VMware"
  s.homepage      = 'https://github.com/cloudfoundry/bosh'
  s.license       = 'Apache 2.0'
  s.email         = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- bin/* lib/*`.split("\n") + %w(README)
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(bosh)

  s.add_dependency "bosh_common", "~>#{version}"
  s.add_dependency "json_pure", "~>1.7.6"
  s.add_dependency "highline", "~>1.6.2"
  s.add_dependency "progressbar", "~>0.9.0"
  s.add_dependency "httpclient", "=2.2.4"
  s.add_dependency "terminal-table", "~>1.4.3"
  s.add_dependency "blobstore_client", "~>#{version}"
  s.add_dependency "net-ssh", ">=2.2.1"
  s.add_dependency "net-ssh-gateway", "~>1.1.0"
  s.add_dependency "net-scp", "~>1.1.0"
  s.add_dependency "netaddr", "~>1.5.0"
  s.add_dependency "archive-tar-minitar", "~>0.5"
  s.add_dependency "haddock"

end
