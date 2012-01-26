libdir = File.join(File.dirname(__FILE__), "lib")
$:.unshift(libdir) unless $:.include?(libdir)

require "common/version"

gemspec = Gem::Specification.new do |s|
  s.name         = "bosh_common"
  s.version      = Bosh::Common::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh Common"
  s.description  = s.summary
  s.authors      = [ "Vadim Spivak" ]
  s.email        = "vspivak@vmware.com"
  s.homepage     = "http://vmware.com"
  s.require_path = "lib"
  s.files        = %w(README Rakefile) + Dir.glob("{lib}/**/*")

  s.add_development_dependency "rspec"
end
