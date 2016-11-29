# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = 'bosh-stemcell'
  spec.version       = '0.0.0.unpublished'
  spec.authors       = 'Pivotal'
  spec.email         = 'support@cloudfoundry.com'
  spec.description   = 'Bosh::Stemcell provides tools to manage stemcells'
  spec.summary       = 'Bosh::Stemcell provides tools to manage stemcells'
  spec.homepage      = 'https://github.com/cloudfoundry/bosh'
  spec.license       = 'Apache 2.0'

  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files         = Dir['README.md', 'lib/**/*'].select{ |f| File.file? f }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w[lib]

  spec.add_dependency 'bosh-core'
end
