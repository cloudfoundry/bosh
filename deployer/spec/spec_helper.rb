# Copyright (c) 2009-2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require "deployer"
require "cli"
require "bosh/cli/commands/micro"

def spec_asset(filename)
  File.expand_path("../assets/#{filename}", __FILE__)
end

def internal_to *args, &block
  example = describe *args, &block
  klass = args[0]
  if klass.is_a? Class
    saved_private_instance_methods = klass.private_instance_methods
    example.before do
      klass.class_eval { public *saved_private_instance_methods }
    end
    example.after do
      klass.class_eval { private *saved_private_instance_methods }
    end
  end
end

RSpec.configure do |c|
  c.fail_fast = true if ENV['BOSH_DEPLOYER_DIR']
end
