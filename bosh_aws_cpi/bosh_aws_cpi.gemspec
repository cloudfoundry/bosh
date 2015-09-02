# coding: utf-8
require File.expand_path('../lib/cloud/aws/version', __FILE__)

version = Bosh::AwsCloud::VERSION

Gem::Specification.new do |spec|
  spec.name         = 'bosh_aws_cpi'
  spec.version      = version
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH AWS CPI'
  spec.description  = "BOSH AWS CPI"
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['README.md', 'bin/**/*', 'lib/**/*', 'scripts/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables  = %w(aws_cpi bosh_aws_console)

  spec.add_dependency 'aws-sdk',       '1.60.2'
  spec.add_dependency 'bosh_common',   "~>#{version}"
  spec.add_dependency 'bosh_cpi',      "~>#{version}"
  spec.add_dependency 'bosh-registry', "~>#{version}"
  spec.add_dependency 'httpclient',    '=2.4.0'
  spec.add_dependency 'yajl-ruby',     '>=0.8.2'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
end
