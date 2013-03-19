require 'spec_helper'
require 'bosh_agent/platform/microcloud'

describe Bosh::Agent::Platform::Microcloud, dummy_infrastructure: true do
  let(:platform) { Bosh::Agent::Platform::Microcloud.new }

  it "is a subclass of Platform::Ubuntu" do
    platform.should be_a_kind_of Bosh::Agent::Platform::Ubuntu
  end

  it "does not call @network.setup_networking" do
    platform.instance_variable_get(:@network).should_not_receive(:setup_networking)
    platform.setup_networking
  end

end