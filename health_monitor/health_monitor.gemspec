require File.dirname(__FILE__) + "/lib/health_monitor/version"

Gem::Specification.new do |s|
  s.name         = "health_monitor"
  s.version      = Bosh::HealthMonitor::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH Health Montior"
  s.description  = s.summary
  s.author       = "VMware"
  s.homepage = 'https://github.com/cloudfoundry/bosh'
  s.license = 'Apache 2.0'
  s.email        = "support@cloudfoundry.com"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")



  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README Rakefile)
  s.require_path = "lib"

  s.add_dependency "eventmachine", "~> 0.12.10"
  s.add_dependency "logging", "~> 1.5.0"
  s.add_dependency "em-http-request", "~> 0.3.0"
  s.add_dependency "nats", "~> 0.4.28"
  s.add_dependency "yajl-ruby", "~> 1.1.0"
  s.add_dependency "uuidtools"
  s.add_dependency "thin"
  s.add_dependency "sinatra", "~> 1.2.8"

  s.bindir      = 'bin'
  s.executables << 'console'
  s.executables << 'health_monitor'
  s.executables << 'listener'
end
