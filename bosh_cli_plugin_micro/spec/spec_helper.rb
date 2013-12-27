require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'cli'
require 'bosh/cli/commands/micro'
require 'fakefs/spec_helpers'

def spec_asset(filename)
  File.expand_path("../assets/#{filename}", __FILE__)
end

def internal_to(*args, &block)
  example = describe(*args, &block)
  klass = args[0]

  if klass.is_a?(Class)
    saved_private_instance_methods = klass.private_instance_methods

    example.before do
      klass.class_eval { public(*saved_private_instance_methods) }
    end

    example.after do
      klass.class_eval { private(*saved_private_instance_methods) }
    end
  end
end

RSpec.configure do |c|
  c.fail_fast = true if ENV['BOSH_DEPLOYER_DIR']
end
