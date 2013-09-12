require 'spec_helper'

module Bosh::Agent
  module Platform::Centos
    describe Adapter, dummy_infrastructure: true do
      it 'should create the class for the disk' do
        subject.instance_variable_get(:@disk).should be_an_instance_of Platform::Centos::Disk
      end

      it 'should create the class for the logrotate' do
        subject.instance_variable_get(:@logrotate).should be_an_instance_of Platform::Linux::Logrotate
      end

      it 'should create the class for the password' do
        subject.instance_variable_get(:@password).should be_an_instance_of Platform::Linux::Password
      end

      it 'should create the class for the network' do
        subject.instance_variable_get(:@network).should be_an_instance_of Platform::Rhel::Network
      end
    end
  end
end
