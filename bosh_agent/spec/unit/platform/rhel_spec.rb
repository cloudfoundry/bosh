require 'spec_helper'

describe Bosh::Agent::Platform::Rhel, dummy_infrastructure: true do

  it 'initializes the correct implementations' do
    subject.instance_variable_get(:@disk).should be_an_instance_of Bosh::Agent::Platform::Linux::Disk
    subject.instance_variable_get(:@password).should be_an_instance_of Bosh::Agent::Platform::Linux::Password
    subject.instance_variable_get(:@network).should be_an_instance_of Bosh::Agent::Platform::Rhel::Network
    subject.instance_variable_get(:@logrotate).should be_an_instance_of Bosh::Agent::Platform::Linux::Logrotate
  end

end
