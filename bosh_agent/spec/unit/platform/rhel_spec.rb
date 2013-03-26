require 'spec_helper'
require 'bosh_agent/platform/rhel'

describe Bosh::Agent::Platform::Rhel, dummy_infrastructure: true do
  let(:platform) { Bosh::Agent::Platform::Rhel.new }

  it "initializes the correct implementations" do
    platform.instance_variable_get(:@disk).should be_a_kind_of Bosh::Agent::Platform::Rhel::Disk
    platform.instance_variable_get(:@password).should be_a_kind_of Bosh::Agent::Platform::Rhel::Password
    platform.instance_variable_get(:@network).should be_a_kind_of Bosh::Agent::Platform::Rhel::Network
    platform.instance_variable_get(:@logrotate).should be_a_kind_of Bosh::Agent::Platform::Rhel::Logrotate
  end

end