# coding: utf-8
require File.expand_path('../lib/blobstore_client/version', __FILE__)

version = Bosh::Blobstore::Client::VERSION

Gem::Specification.new do |s|
  s.name         = 'blobstore_client'
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'BOSH blobstore client'
  s.description  = "BOSH blobstore client\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'VMware'
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- bin/* lib/* config/*`.split("\n") + %w(README.md)
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables  = %w(blobstore_client_console)

  s.add_dependency 'aws-sdk',         '1.60.2'
  s.add_dependency 'fog-aws',         '<=0.1.1'
  s.add_dependency 'fog',             '~>1.27.0'
  s.add_dependency 'httpclient',      '=2.4.0'
  s.add_dependency 'multi_json',      '~> 1.1'
  s.add_dependency 'ruby-atmos-pure', '~> 1.0.5'
  s.add_dependency 'bosh_common',     "~>#{version}"

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'rspec-instafail'
  s.add_development_dependency 'thin'
  s.add_development_dependency 'simple_blobstore_server'
end
