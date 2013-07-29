require File.dirname(__FILE__) + "/lib/cloud/warden/version"
version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "bosh_warden_cpi"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH Warden CPI"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- lib/* db/*`.split("\n") + %w(README)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"

  s.add_dependency "bosh_common"
  s.add_dependency "bosh_cpi"
  s.add_dependency "warden-protocol"
  s.add_dependency "warden-client"
  s.add_dependency "sequel"
  s.add_dependency "yajl-ruby"

  # s.add_development_dependency "vagrant", "~> 1.0.7" # Abhi/Kai: Disabled to merge master into warden-cpi branch
  s.add_development_dependency "librarian"
end
