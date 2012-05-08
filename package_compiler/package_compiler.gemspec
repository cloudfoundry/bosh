require File.dirname(__FILE__) + "/lib/package_compiler/version"

Gem::Specification.new do |s|
  s.name         = "package_compiler"
  s.version      = Bosh::PackageCompiler::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh package compiler"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(package_compiler)

  s.add_dependency "agent_client", "~>0.1.1"
  s.add_dependency "blobstore_client", "~>0.3.13"
  s.add_dependency "yajl-ruby"
  s.add_dependency "trollop", "~> 1.16"
end
