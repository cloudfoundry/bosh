require File.dirname(__FILE__) + "/lib/director/version"

Gem::Specification.new do |s|
  s.name         = "director"
  s.version      = Bosh::Director::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH Director"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")



  s.files        = `git ls-files -- lib/*`.split("\n") + %w(CHANGELOG)
  s.require_path = "lib"

  s.add_dependency  "bcrypt-ruby"
  s.add_dependency  "blobstore_client"
  s.add_dependency  "bosh_common"
  s.add_dependency  "bosh_encryption"
  s.add_dependency  "bosh_cpi"
  s.add_dependency  "bosh_openstack_cpi"
  s.add_dependency  "bosh_aws_cpi"
  s.add_dependency  "bosh_vcloud_cpi"
  s.add_dependency  "bosh_vsphere_cpi"
  s.add_dependency  "eventmachine"
  s.add_dependency  "httpclient"
  s.add_dependency  "nats", "~> 0.4.28"
  s.add_dependency  "netaddr"
  s.add_dependency  "rack-test"         # needed for console
  s.add_dependency  "rake"
  s.add_dependency  "redis"
  s.add_dependency  "resque"
  s.add_dependency  "sequel"
  s.add_dependency  "sinatra", "~> 1.2.8"
  s.add_dependency  "thin"
  s.add_dependency  "uuidtools"
  s.add_dependency  "yajl-ruby"

  s.bindir      = 'bin'
  s.executables << 'console'
  s.executables << 'director'
  s.executables << 'drain_workers'
  s.executables << 'worker'
end
