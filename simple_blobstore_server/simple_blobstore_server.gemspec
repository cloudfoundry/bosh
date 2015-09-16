# coding: utf-8
require File.expand_path('../lib/simple_blobstore_server/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name        = 'simple_blobstore_server'
  spec.version     = Bosh::SimpleBlobstoreServer::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.summary     = 'BOSH Simple Blobstore Server'
  spec.description = "BOSH Simple Blobstore Server"
  spec.author      = 'VMware'
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache 2.0'
  spec.email       = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables << 'simple_blobstore_server'

  spec.add_dependency 'thin',    '~>1.5.0'
  spec.add_dependency 'sinatra', '~> 1.4.2'

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rack-test'
end
