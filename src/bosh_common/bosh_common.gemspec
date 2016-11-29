# coding: utf-8
Gem::Specification.new do |spec|
  spec.name         = 'bosh_common'
  spec.version      = '0.0.0.unpublished'
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH common'
  spec.description  = "BOSH common"
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'

  spec.add_dependency 'semi_semantic', '~>1.2.0'
  spec.add_dependency 'logging',       '~>1.8.2'
end
