# coding: utf-8
require File.expand_path('../lib/bosh_cli_plugin_aws/version', __FILE__)

version = Bosh::AwsCliPlugin::VERSION

Gem::Specification.new do |spec|
  spec.name        = 'bosh_cli_plugin_aws'
  spec.version     = version
  spec.platform    = Gem::Platform::RUBY
  spec.summary     = 'BOSH plugin to easily create and delete an AWS VPC'
  spec.description = "BOSH plugin to easily create and delete an AWS VPC"
  spec.author      = 'VMware'
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache 2.0'
  spec.email       = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files         = Dir['lib/**/*', 'migrations/**/*', 'templates/**/*'].select{ |f| File.file? f }
  spec.require_paths = ['lib', 'migrations']

  spec.add_dependency 'bosh-core',             "~>#{version}"
  spec.add_dependency 'bosh_cli',              "~>#{version}"
  spec.add_dependency 'bosh_aws_cpi',          "~>2.0.0"
  spec.add_dependency 'bosh_cli_plugin_micro', "~>#{version}"
  spec.add_dependency 'bosh-stemcell',         "~>#{version}"

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'webmock'
end
