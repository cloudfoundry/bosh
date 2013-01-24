require File.dirname(__FILE__) + "/lib/encryption/version"

Gem::Specification.new do |s|
  s.name         = "bosh_encryption"
  s.version      = Bosh::Encryption::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH encryption"
  s.description  = s.summary
  s.license      = "Apache-2"
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.require_path = "lib"

  s.add_dependency "gibberish", "~>1.2.0"
  s.add_dependency "uuidtools", "~>2.1.2"
  s.add_dependency "yajl-ruby"
end
