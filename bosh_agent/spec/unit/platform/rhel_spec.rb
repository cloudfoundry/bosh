require 'spec_helper'

module Bosh::Agent
  module  Platform::Rhel
    describe Adapter, dummy_infrastructure: true do
      it 'initializes the correct implementations' do
        subject.instance_variable_get(:@disk).should be_an_instance_of Platform::Linux::Disk
        subject.instance_variable_get(:@password).should be_an_instance_of Platform::Linux::Password
        subject.instance_variable_get(:@network).should be_an_instance_of Platform::Rhel::Network
        subject.instance_variable_get(:@logrotate).should be_an_instance_of Platform::Linux::Logrotate
      end
    end
  end
end
