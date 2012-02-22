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

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"

  s.add_dependency "aws-s3"
  s.add_dependency "httpclient"
  s.add_dependency "json"
  s.add_dependency "ruby-atmos-pure", ">= 1.0.5"
  s.add_dependency "uuidtools"
end
