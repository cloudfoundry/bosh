$:.unshift(File.expand_path("../lib", __FILE__))

require "ruby_vcloud_sdk/version"

Gem::Specification.new do |s|
  s.name         = "ruby_vcloud_sdk"
  s.version      = VCloudSdk::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH vCloud API client"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"

  s.add_dependency("builder")
  s.add_dependency("httpclient")
  s.add_dependency("rest-client")
  s.add_dependency("nokogiri", "~> 1.5")
end
