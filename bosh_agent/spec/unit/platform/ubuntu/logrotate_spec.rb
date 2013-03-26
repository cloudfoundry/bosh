# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/ubuntu/logrotate'

describe Bosh::Agent::Platform::Ubuntu::Logrotate do
  let(:logrotate) { Bosh::Agent::Platform::Ubuntu::Logrotate.new }

  it "refers to the correct template directory" do
    logrotate.instance_variable_get(:@template_src).should match %r|bosh_agent/platform/ubuntu/templates/logrotate.erb|
  end

end
