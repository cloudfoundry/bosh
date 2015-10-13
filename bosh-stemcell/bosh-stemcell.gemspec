# coding: utf-8
require File.expand_path('../lib/bosh/stemcell/version', __FILE__)

version = Bosh::Stemcell::VERSION

Gem::Specification.new do |spec|
  spec.name          = 'bosh-stemcell'
  spec.version       = version
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

  spec.add_dependency 'bosh_aws_cpi', "=2.1.0"
  spec.add_dependency 'bosh-core', "~>#{version}"

  spec.add_development_dependency 'fakefs'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rspec-instafail'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'serverspec', '0.15.4'
  spec.add_development_dependency 'specinfra', '1.15.0'
  spec.add_development_dependency 'foodcritic'
end
