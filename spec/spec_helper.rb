SPEC_ROOT = File.dirname(__FILE__)
RELEASE_ROOT = File.expand_path(File.join(SPEC_ROOT, '..'))

require File.expand_path('../src/spec/shared/spec_helper', SPEC_ROOT)

require 'json'
require 'openssl'
require 'tempfile'
require 'yaml'

require 'bosh/template/evaluation_context'

require 'bosh/template/test'

require_relative './support/template_example_group'

def asset_path(name)
  File.join(SPEC_ROOT, 'support', name)
end

def template_file(template_name)
  File.expand_path(File.join(RELEASE_ROOT, template_name))
end
