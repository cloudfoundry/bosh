# coding: utf-8
require File.expand_path('../lib/cli/version', __FILE__)

version = Bosh::Cli::VERSION

Gem::Specification.new do |spec|
  spec.name        = 'bosh_cli'
  spec.version     = version
  spec.platform    = Gem::Platform::RUBY
  spec.summary     = 'BOSH CLI'
  spec.description = "BOSH CLI"
  spec.author      = 'VMware'
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache 2.0'
  spec.email       = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['bin/**/*', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables  = %w(bosh)

  spec.add_dependency 'bosh_common', "~>#{version}"
  spec.add_dependency 'bosh-template', "~>#{version}"
  spec.add_dependency 'cf-uaa-lib',  '~>3.2.1'
  spec.add_dependency 'json_pure',   '~>1.7'
  spec.add_dependency 'highline',    '~>1.6.2'
  spec.add_dependency 'progressbar', '~>0.9.0'
  spec.add_dependency 'httpclient',  '=2.4.0'
  spec.add_dependency 'terminal-table',   '~>1.4.3'
  spec.add_dependency 'blobstore_client', "~>#{version}"
  spec.add_dependency 'net-ssh',          '>=2.2.1'
  spec.add_dependency 'net-ssh-gateway',  '~>1.2.0'
  spec.add_dependency 'net-scp', '~>1.1.0'
  spec.add_dependency 'netaddr', '~>1.5.0'
  spec.add_dependency 'minitar', '~>0.5.4'

  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rspec-instafail'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'timecop', '~>0.7.1'
  spec.add_development_dependency 'fakefs'
  spec.add_development_dependency 'vcr'
end
