# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = 'bosh-dev'
  spec.version       = '0.0.1.unpublished'
  spec.authors       = 'Pivotal'
  spec.email         = 'support@cloudfoundry.com'
  spec.description   = 'Bosh::Dev makes development on BOSH easier'
  spec.summary       = 'Bosh::Dev makes development on BOSH easier'
  spec.homepage      = 'https://github.com/cloudfoundry/bosh'
  spec.license       = 'Apache 2.0'

  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files         = `git ls-files -- lib/*`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w[lib]

  spec.add_dependency 'bosh_common'
  spec.add_dependency 'bosh-core'
  spec.add_dependency 'bosh-stemcell'
  spec.add_dependency 'peach'
  spec.add_dependency 'bosh_cli'
  spec.add_dependency 'bosh_cli_plugin_aws'
  spec.add_dependency 'bundler'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'fakefs'
  spec.add_development_dependency 'rugged'
end
