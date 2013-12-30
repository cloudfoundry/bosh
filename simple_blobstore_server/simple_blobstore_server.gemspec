# coding: utf-8
require File.expand_path('../lib/simple_blobstore_server/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'simple_blobstore_server'
  s.version     = Bosh::SimpleBlobstoreServer::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'BOSH Simple Blobstore Server'
  s.description = "BOSH Simple Blobstore Server\n#{`git rev-parse HEAD`[0, 6]}"
  s.author      = 'VMware'
  s.homepage    = 'https://github.com/cloudfoundry/bosh'
  s.license     = 'Apache 2.0'
  s.email       = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/*`.split("\n") + %w(README)
  s.require_path = 'lib'

  s.add_dependency 'thin',    '~>1.5.0'
  s.add_dependency 'sinatra', '~> 1.4.2'

  s.bindir      = 'bin'
  s.executables << 'simple_blobstore_server'
end
