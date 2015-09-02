# coding: utf-8
require File.expand_path('../lib/bosh_cli_plugin_aws/version', __FILE__)

version = Bosh::AwsCliPlugin::VERSION

Gem::Specification.new do |s|
  s.name        = 'bosh_cli_plugin_aws'
  s.version     = version
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'BOSH plugin to easily create and delete an AWS VPC'
  s.description = "BOSH plugin to easily create and delete an AWS VPC"
  s.author      = 'VMware'
  s.homepage    = 'https://github.com/cloudfoundry/bosh'
  s.license     = 'Apache 2.0'
  s.email       = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files         = Dir['lib/**/*', 'migrations/**/*', 'templates/**/*'].select{ |f| File.file? f }
  s.require_paths = ['lib', 'migrations']

  s.add_dependency 'bosh-core',             "~>#{version}"
  s.add_dependency 'bosh_cli',              "~>#{version}"
  s.add_dependency 'bosh_aws_cpi',          "~>#{version}"
  s.add_dependency 'bosh_cli_plugin_micro', "~>#{version}"
  s.add_dependency 'bosh-stemcell',         "~>#{version}"

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'webmock'
end
