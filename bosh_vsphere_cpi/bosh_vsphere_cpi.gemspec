# coding: utf-8
require File.expand_path('../lib/cloud/vsphere/version', __FILE__)

version = Bosh::Clouds::VSphere::VERSION

Gem::Specification.new do |s|
  s.name        = 'bosh_vsphere_cpi'
  s.version     = version
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'BOSH VSphere CPI'
  s.description = "BOSH VSphere CPI\n#{`git rev-parse HEAD`[0, 6]}"
  s.author      = 'VMware'
  s.homepage    = 'https://github.com/cloudfoundry/bosh'
  s.license     = 'Apache 2.0'
  s.email       = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/*`.split("\n")
  s.require_path = 'lib'
  s.bindir       = 'bin'

  s.executables = %w(vsphere_cpi vsphere_cpi_console)

  s.add_dependency 'bosh_common', "~>#{version}"
  s.add_dependency 'bosh_cpi',    "~>#{version}"
  s.add_dependency 'membrane',    '~>1.1.0'
  s.add_dependency 'builder',     '~>3.1.4'
  s.add_dependency 'nokogiri',    '~>1.6.6'
  s.add_dependency 'httpclient',  '=2.4.0'
  s.add_dependency 'mono_logger', '~>1.1.0'

  s.add_development_dependency 'timecop', '~>0.7.1'
  s.add_development_dependency 'rake', '~>10.0'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'rspec-instafail'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'fakefs'
end
