libdir = File.join(File.dirname(__FILE__), "lib")
$:.unshift(libdir) unless $:.include?(libdir)

require "cloud/vsphere/version"

gemspec = Gem::Specification.new do |s|
  s.name         = "vsphere_cpi"
  s.version      = Bosh::Clouds::VSphere::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh VSphere CPI"
  s.description  = s.summary
  s.authors      = [ "Vadim Spivak" ]
  s.email        = "vspivak@vmware.com"
  s.homepage     = "http://vmware.com"
  s.require_path = "lib"
  s.files        = %w(README Rakefile) + Dir.glob("{lib}/**/*")

  s.add_dependency "bosh_cpi"
  s.add_dependency "ruby_vim_sdk"
  s.add_dependency "uuidtools"
  s.add_dependency "sequel"
  s.add_dependency "sqlite3"

  s.add_development_dependency "rspec"
end
