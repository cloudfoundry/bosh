require 'spec_helper'
require 'bosh_agent/platform/ubuntu'

describe Bosh::Agent::Platform::Ubuntu, dummy_infrastructure: true do
  let(:platform) { Bosh::Agent::Platform::Ubuntu.new }

  it "initializes the correct implementations" do
    platform.instance_variable_get(:@disk).should be_a_kind_of Bosh::Agent::Platform::Ubuntu::Disk
    platform.instance_variable_get(:@password).should be_a_kind_of Bosh::Agent::Platform::Ubuntu::Password
    platform.instance_variable_get(:@network).should be_a_kind_of Bosh::Agent::Platform::Ubuntu::Network
    platform.instance_variable_get(:@logrotate).should be_a_kind_of Bosh::Agent::Platform::Ubuntu::Logrotate
  end

end