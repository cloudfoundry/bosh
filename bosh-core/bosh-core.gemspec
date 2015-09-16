# coding: utf-8
require File.expand_path('../lib/bosh/core/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name        = 'bosh-core'
  spec.version     = Bosh::Core::VERSION
  spec.authors     = 'Pivotal'
  spec.email       = 'support@cloudfoundry.com'
  spec.description = 'Bosh::Core provides things BOSH needs to exist'
  spec.summary     = 'Bosh::Core provides things BOSH needs to exist'
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache 2.0'

  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files         = Dir['lib/**/*'].select{ |f| File.file? f }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w[lib]

  spec.add_dependency 'gibberish', '~>1.4.0'
  spec.add_dependency 'yajl-ruby', '~>1.2.0'

  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rspec-instafail'
end
