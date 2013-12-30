# coding: utf-8
require File.expand_path('../lib/cloud/version', __FILE__)

version = Bosh::Clouds::VERSION

Gem::Specification.new do |s|
  s.name        = 'bosh_cpi'
  s.version     = version
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'BOSH CPI'
  s.description = "BOSH CPI\n#{`git rev-parse HEAD`[0, 6]}"
  s.author      = 'VMware'
  s.homepage    = 'https://github.com/cloudfoundry/bosh'
  s.license     = 'Apache 2.0'
  s.email       = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.require_path = 'lib'

  s.add_dependency 'bosh_common', "~>#{version}"
end
