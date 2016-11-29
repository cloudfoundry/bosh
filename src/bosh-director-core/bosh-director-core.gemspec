# coding: utf-8

Gem::Specification.new do |spec|
  spec.name        = 'bosh-director-core'
  spec.version     = '0.0.0.unpublished'
  spec.authors     = 'Pivotal'
  spec.email       = 'support@cloudfoundry.com'
  spec.description = 'Bosh::Director::Core provides common Director code for Director and Microbosh Deployer'
  spec.summary     = 'Bosh::Director::Core provides common Director code for Director and Microbosh Deployer'
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache 2.0'

  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files         = Dir['lib/**/*'].select{ |f| File.file? f }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w[lib]

  spec.add_dependency 'bosh_common'
  spec.add_dependency 'bosh-template'
end
