# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + "/lib/cli/version"

Gem::Specification.new do |s|
  s.name         = "bosh_cli"
  s.version      = Bosh::Cli::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH CLI"
  s.description  = "BOSH command-line tool for release engineering and deployment"
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- bin/* lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(bosh)

  s.add_dependency "json_pure", "~>1.6.1"
  s.add_dependency "highline", "~>1.6.2"
  s.add_dependency "progressbar", "~>0.9.0"
  s.add_dependency "httpclient", ">=2.2.4", "<=2.2.4"
  s.add_dependency "terminal-table", "~>1.4.2"
  s.add_dependency "blobstore_client", "~>0.4.0"
  s.add_dependency "net-ssh", "~>2.2.1"
  s.add_dependency "net-ssh-gateway", "~>1.1.0"
  s.add_dependency "net-scp", "~>1.0.4"
  s.add_dependency "netaddr", "~>1.5.0"
end
