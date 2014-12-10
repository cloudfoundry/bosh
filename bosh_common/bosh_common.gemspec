# coding: utf-8
require File.expand_path('../lib/common/version', __FILE__)

Gem::Specification.new do |s|
  s.name         = 'bosh_common'
  s.version      = Bosh::Common::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'BOSH common'
  s.description  = "BOSH common\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'VMware'
  s.homepage = 'https://github.com/cloudfoundry/bosh'
  s.license = 'Apache 2.0'
  s.email        = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- lib/*`.split("\n")
  s.require_path = 'lib'

  s.add_dependency 'semi_semantic', '~>1.1.0'
  s.add_dependency 'logging',       '~>1.8.2'
end
