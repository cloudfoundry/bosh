# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + "/lib/blobstore_client/version"

Gem::Specification.new do |s|
  s.name         = "blobstore_client"
  s.version      = Bosh::Blobstore::Client::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH blobstore client"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- bin/* lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(blobstore_client_console)

  s.add_dependency "aws-s3", "~> 0.6.2"
  s.add_dependency "fog", "~>1.5.0"
  s.add_dependency "httpclient", ">=2.2"
  s.add_dependency "multi_json", "~> 1.1.0"
  s.add_dependency "ruby-atmos-pure", "~> 1.0.5"
  s.add_dependency "uuidtools", "~> 2.1.2"
  s.add_dependency "bosh_common", "~> 0.5"
end
