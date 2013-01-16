# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bosh_aws_bootstrap/version'

Gem::Specification.new do |gem|
  gem.name          = "bosh_aws_bootstrap"
  gem.version       = Bosh::Aws::Bootstrap::VERSION
  gem.authors       = ["VMware Inc"]
  gem.email         = ["support@vmware.com"]
  gem.description   = %q{BOSH plugin to easily create and delete an AWS VPC}
  gem.summary       = %q{BOSH plugin to easily create and delete an AWS VPC}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.test_files    = gem.files.grep(%r{^spec/})
  gem.require_paths = ["lib"]

  gem.add_dependency "bosh_cli", ">=1.0.4"
  gem.add_dependency "aws-sdk", ">=1.8.0"
end
