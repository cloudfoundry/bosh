libdir = File.join(File.dirname(__FILE__), "lib")
$:.unshift(libdir) unless $:.include?(libdir)

require "cloud/version"

gemspec = Gem::Specification.new do |s|
  s.name         = "bosh_cpi"
  s.version      = Bosh::Clouds::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh CPI"
  s.description  = s.summary
  s.authors      = [ "Vadim Spivak" ]
  s.email        = "vspivak@vmware.com"
  s.homepage     = "http://vmware.com"
  s.require_path = "lib"
  s.files        = %w(README Rakefile) + Dir.glob("{lib}/**/*")

  s.add_dependency "bosh_common"
  s.add_development_dependency "rspec"
end
