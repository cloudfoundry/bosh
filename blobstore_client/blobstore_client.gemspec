libdir = File.join(File.dirname(__FILE__), "lib")
$:.unshift(libdir) unless $:.include?(libdir)

require "blobstore_client/version"

gemspec = Gem::Specification.new do |s|
  s.name         = "blobstore_client"
  s.version      = Bosh::Blobstore::Client::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh blobstore client"
  s.description  = s.summary
  s.authors      = [ "Vadim Spivak", "Oleg Shaldybin" ]
  s.email        = "vspivak@vmware.com"
  s.homepage     = "http://vmware.com"
  s.require_path = "lib"
  s.files        = %w(README Rakefile) + Dir.glob("{lib}/**/*")

  s.add_dependency "httpclient"
  s.add_dependency "aws-s3"
  s.add_dependency "uuidtools"
  s.add_dependency "ruby-atmos"

  s.add_development_dependency "rspec"
end
