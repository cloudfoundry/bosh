# coding: utf-8
require File.expand_path('../lib/bosh/registry/version', __FILE__)

Gem::Specification.new do |s|
  s.name         = 'bosh-registry'
  s.version      = Bosh::Registry::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'BOSH Registry'
  s.description  = "BOSH Registry\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'VMware'
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/* db/*`.split("\n") + %w(README.md)
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables  = %w(bosh-registry bosh-registry-migrate)

  s.add_dependency 'sequel',    '~>3.43.0'
  s.add_dependency 'sinatra',   '~>1.4.2'
  s.add_dependency 'thin',      '~>1.5.0'
  s.add_dependency 'yajl-ruby', '~>1.1.0'
  s.add_dependency 'fog',       '~>1.14.0'
  s.add_dependency 'aws-sdk',   '1.44.0'
end
