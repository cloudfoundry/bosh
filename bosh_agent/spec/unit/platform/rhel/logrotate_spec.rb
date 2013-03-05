# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/rhel/logrotate'

describe Bosh::Agent::Platform::Rhel::Logrotate do

  let(:logrotate) { Bosh::Agent::Platform::Rhel::Logrotate.new }

  it "refers to the correct template directory" do
    logrotate.instance_variable_get(:@template_src).should match %r|bosh_agent/platform/rhel/templates/logrotate.erb|
    File.exists?(logrotate.instance_variable_get(:@template_src)).should be_true
  end

end
