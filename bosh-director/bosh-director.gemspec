# coding: utf-8
require File.expand_path('../lib/bosh/director/version', __FILE__)

version = Bosh::Director::VERSION

Gem::Specification.new do |s|
  s.name         = 'bosh-director'
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'BOSH Director'
  s.description  = "BOSH Director\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'VMware'
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/* db/*`.split("\n")
  s.require_path = 'lib'

  s.add_dependency 'bcrypt-ruby',        '~>3.0.1'
  s.add_dependency 'blobstore_client',   "~>#{version}"
  s.add_dependency 'bosh-core',          "~>#{version}"
  s.add_dependency 'bosh-director-core', "~>#{version}"
  s.add_dependency 'bosh_common',        "~>#{version}"
  s.add_dependency 'bosh-template',      "~>#{version}"
  s.add_dependency 'bosh_cpi',           "~>#{version}"
  s.add_dependency 'bosh_openstack_cpi', "~>#{version}"
  s.add_dependency 'bosh_aws_cpi',       "~>#{version}"
  s.add_dependency 'bosh_vsphere_cpi',   "~>#{version}"
  s.add_dependency 'bosh_vcloud_cpi',    '~>0.7.3'
  s.add_dependency 'eventmachine',       '~>1.0.0'
  s.add_dependency 'fog',              '~>1.27.0'
  s.add_dependency 'httpclient',       '=2.4.0'
  s.add_dependency 'logging',          '~>1.8.2'
  s.add_dependency 'nats',             '=0.5.0.beta.12'
  s.add_dependency 'netaddr',          '~>1.5.0'
  s.add_dependency 'rack-test',        '~>0.6.2' # needed for console
  s.add_dependency 'rake',             '~> 10.0'
  s.add_dependency 'redis',            '~>3.0.2'
  s.add_dependency 'resque',           '~>1.25.0'
  s.add_dependency 'resque-backtrace', '~>0.0.1'
  s.add_dependency 'rufus-scheduler',  '~>2.0.18'
  s.add_dependency 'sequel',           '~>3.43.0'
  s.add_dependency 'sinatra',          '~>1.4.2'
  s.add_dependency 'sys-filesystem',   '~>1.1.0'
  s.add_dependency 'thin',             '~>1.5.0'
  s.add_dependency 'yajl-ruby',        '~>1.2.0'
  s.add_dependency 'membrane',         '~>1.1.0'
  s.add_dependency 'semi_semantic',    '~>1.1.0'
  s.add_dependency 'cf-uaa-lib',       '~>3.2.1'

  s.add_development_dependency 'timecop'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'minitar'
  s.add_development_dependency 'machinist'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'fakefs'
  s.add_development_dependency 'pg'

  s.bindir      = 'bin'
  s.executables << 'bosh-director'
  s.executables << 'bosh-director-console'
  s.executables << 'bosh-director-drain-workers'
  s.executables << 'bosh-director-migrate'
  s.executables << 'bosh-director-scheduler'
  s.executables << 'bosh-director-worker'
end
