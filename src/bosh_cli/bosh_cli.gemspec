# coding: utf-8
Gem::Specification.new do |spec|
  spec.name        = 'bosh_cli'
  spec.version     = '0.0.0.unpublished'
  spec.platform    = Gem::Platform::RUBY
  spec.summary     = 'BOSH CLI'
  spec.description = "BOSH CLI"
  spec.author      = 'VMware'
  spec.homepage    = 'https://github.com/cloudfoundry/bosh'
  spec.license     = 'Apache 2.0'
  spec.email       = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['bin/**/*', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables  = %w(bosh)

  spec.add_dependency 'bosh_common'
  spec.add_dependency 'bosh-template'
  spec.add_dependency 'cf-uaa-lib',  '~>3.2.1'
  spec.add_dependency 'json_pure',   '~>1.7'
  spec.add_dependency 'highline',    '~>1.6.2'
  spec.add_dependency 'progressbar', '~>0.21.0'
  spec.add_dependency 'httpclient',  '=2.7.1'
  spec.add_dependency 'terminal-table',   '~>1.4.3'
  spec.add_dependency 'blobstore_client'
  spec.add_dependency 'net-ssh',          '=2.9.2'
  spec.add_dependency 'net-ssh-gateway',  '~>1.2.0'
  spec.add_dependency 'net-scp', '~>1.1.0'
  spec.add_dependency 'netaddr', '~>1.5.0'
  spec.add_dependency 'minitar', '~>0.5.4'
  spec.add_dependency 'sshkey', '~>1.7.0'
end
