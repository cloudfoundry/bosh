libdir = File.expand_path("../lib", __FILE__)
$:.unshift(libdir) unless $:.include?(libdir)
require "cli/version"

Gem::Specification.new do |s|
  s.name         = "bosh_cli"
  s.version      = Bosh::Cli::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh CLI"
  s.description  = "Bosh command-line tool for release engineering and deployment"
  s.authors      = [ "Oleg Shaldybin" ]
  s.email        = "olegs@vmware.com"
  s.homepage     = "http://vmware.com"
  s.executables  = %w(bosh)
  s.files        = %w(README Rakefile) + Dir.glob("{bin,lib}/**/*")
  s.bindir       = "bin"
  s.require_path = "lib"

  s.add_dependency "json_pure", "~>1.6.1"
  s.add_dependency "highline", "~>1.6.2"
  s.add_dependency "progressbar", "~>0.9.0"
  s.add_dependency "httpclient", "=2.2.1"
  s.add_dependency "terminal-table", "~>1.4.2"
  s.add_dependency "blobstore_client", "=0.3.5"
  s.add_dependency "net-ssh", "~>2.2.1"
  s.add_dependency "net-ssh-gateway", "~>1.1.0"
  s.add_dependency "net-scp", "~>1.0.4"

  s.add_development_dependency "rspec"
end
