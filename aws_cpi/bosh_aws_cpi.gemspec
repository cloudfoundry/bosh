# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + "/lib/cloud/aws/version"

Gem::Specification.new do |s|
  s.name         = "bosh_aws_cpi"
  s.version      = Bosh::AwsCloud::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH AWS CPI"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- bin/* lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(bosh_aws_console)

  s.add_dependency "aws-sdk", ">=1.3.5"
  s.add_dependency "bosh_common", ">=0.4.0"
  s.add_dependency "bosh_cpi", ">=0.4.3"
  s.add_dependency "httpclient", ">=2.2.0"
  s.add_dependency "uuidtools", ">=2.1.2"
  s.add_dependency "yajl-ruby", ">=0.8.2"
end
