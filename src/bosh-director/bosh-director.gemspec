# coding: utf-8
require File.expand_path('../lib/bosh/director/version', __FILE__)

version = Bosh::Director::VERSION

Gem::Specification.new do |spec|
  spec.name         = 'bosh-director'
  spec.version      = version
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH Director'
  spec.description  = 'BOSH Director'
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['db/**/*', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables << 'bosh-director'
  spec.executables << 'bosh-director-console'
  spec.executables << 'bosh-director-drain-workers'
  spec.executables << 'bosh-director-migrate'
  spec.executables << 'bosh-director-scheduler'
  spec.executables << 'bosh-director-sync-dns'
  spec.executables << 'bosh-director-trigger-one-time-sync-dns'
  spec.executables << 'bosh-director-worker'
  spec.executables << 'bosh-backup'
  spec.executables << 'bosh-restore'

  # NOTE: We must specify all transitive BOSH gem dependencies found in the
  # external CPIs, in order to ensure appropriate versions are installed.
  # Also do the same in bosh_cli_plugin_micro.gemspec
  # Review this once CPIs are completely externalized and "micro" goes away.
  # ----------------------------------------------------------------------------
  spec.add_dependency 'bosh_common',        "~>#{version}"
  spec.add_dependency 'bosh-registry',      "~>#{version}"
  # ----------------------------------------------------------------------------

  spec.add_dependency 'bosh-core',          "~>#{version}"
  spec.add_dependency 'bosh-director-core', "~>#{version}"
  spec.add_dependency 'bosh-template',      "~>#{version}"
  spec.add_dependency 'bosh_cpi',           '=2.4.1'

  spec.add_dependency 'bcrypt-ruby',      '~>3.0.1'
  spec.add_dependency 'eventmachine',     '~>1.2.0'
  spec.add_dependency 'httpclient',       '~>2.8.3'
  spec.add_dependency 'logging',          '~>2.2.2'
  spec.add_dependency 'nats',             '~>0.8'
  spec.add_dependency 'netaddr',          '~>1.5.0'
  spec.add_dependency 'rack-test',        '~>0.6.2' # needed for console
  spec.add_dependency 'rake',             '~> 10.0'
  spec.add_dependency 'rufus-scheduler',  '~>2.0.18'
  spec.add_dependency 'sequel',           '~>4.49.0'
  spec.add_dependency 'sinatra',          '~>1.4.2'
  spec.add_dependency 'sys-filesystem',   '~>1.1.0'
  spec.add_dependency 'thin',             '~>1.7.0'
  spec.add_dependency 'membrane',         '~>1.1.0'
  spec.add_dependency 'semi_semantic',    '~>1.2.0'
  spec.add_dependency 'cf-uaa-lib',       '~>3.2.1'
  spec.add_dependency 'talentbox-delayed_job_sequel', '~>4.1.0'
  spec.add_dependency 'unix-crypt',       '~>1.3.0'
end
