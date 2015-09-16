# coding: utf-8
require File.expand_path('../lib/blobstore_client/version', __FILE__)

version = Bosh::Blobstore::Client::VERSION

Gem::Specification.new do |spec|
  spec.name         = 'blobstore_client'
  spec.version      = version
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH blobstore client'
  spec.description  = "BOSH blobstore client"
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['README.md', 'bin/**/*', 'config/**/*', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables  = %w(blobstore_client_console)

  spec.add_dependency 'aws-sdk',         '1.60.2'
  spec.add_dependency 'fog-aws',         '<=0.1.1'
  spec.add_dependency 'fog',             '~>1.31.0'
  spec.add_dependency 'httpclient',      '=2.4.0'
  spec.add_dependency 'multi_json',      '~> 1.1'
  spec.add_dependency 'bosh_common',     "~>#{version}"

  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rspec-instafail'
  spec.add_development_dependency 'thin'
  spec.add_development_dependency 'simple_blobstore_server'
end
