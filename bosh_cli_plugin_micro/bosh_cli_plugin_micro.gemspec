# coding: utf-8
require File.expand_path('../lib/bosh/deployer/version', __FILE__)

version = Bosh::Deployer::VERSION

Gem::Specification.new do |spec|
  spec.name        = 'bosh_cli_plugin_micro'
  spec.version     = version
  spec.platform    = Gem::Platform::RUBY
  spec.summary     = 'BOSH CLI plugin for Micro BOSH deployment'
  spec.description = "BOSH CLI plugin for Micro BOSH deployment"
  spec.author      = 'VMware'
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache 2.0'
  spec.email       = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files         = Dir['README.rdoc', 'config/**/*', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_paths = ['lib', 'config']

  spec.add_dependency 'sqlite3',     '~>1.3.7'
  spec.add_dependency 'mono_logger', '~>1.1.0'

  # NOTE: We must specify all transitive BOSH gem dependencies found in the
  # external CPIs, in order to ensure appropriate versions are installed.
  # Also do the same in bosh-director.gemspec
  # ----------------------------------------------------------------------------
  spec.add_dependency 'bosh_common',        "~>#{version}"
  spec.add_dependency 'bosh_cpi',           "~>#{version}"
  spec.add_dependency 'bosh-registry',      "~>#{version}"
  # ----------------------------------------------------------------------------

  spec.add_dependency 'agent_client',       "~>#{version}"
  spec.add_dependency 'blobstore_client',   "~>#{version}"
  spec.add_dependency 'bosh_cli',           "~>#{version}"
  spec.add_dependency 'bosh-core',          "~>#{version}"
  spec.add_dependency 'bosh-director-core', "~>#{version}"
  spec.add_dependency 'bosh-stemcell',      "~>#{version}"

  spec.add_dependency 'bosh_aws_cpi',       '=2.1.0'
  spec.add_dependency 'bosh_openstack_cpi', '=2.1.0'
  spec.add_dependency 'bosh_vcloud_cpi',    '=0.11.0'
  spec.add_dependency 'bosh_vsphere_cpi',   '=2.1.0'
  spec.add_dependency 'fog-google',         '=0.1.0'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'fakefs'
  spec.add_development_dependency 'timecop'
end
