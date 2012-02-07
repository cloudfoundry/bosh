libdir = File.join(File.dirname(__FILE__), "lib")
$:.unshift(libdir) unless $:.include?(libdir)

require "package_compiler/version"

gemspec = Gem::Specification.new do |s|
  s.name         = "package_compiler"
  s.version      = Bosh::PackageCompiler::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh package compiler"
  s.description  = s.summary
  s.authors      = [ "Bosh eng" ]
  s.homepage     = "http://vmware.com"
  s.require_path = "lib"
  s.files        = %w(README Rakefile) + Dir.glob("{lib}/**/*")

  s.add_dependency "agent_client"
  s.add_dependency "blobstore_client"
  s.add_dependency "yajl-ruby"

  s.add_development_dependency "rspec"
end
