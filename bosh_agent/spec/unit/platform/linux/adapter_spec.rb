require 'spec_helper'

module Bosh::Agent
  module Platform::Linux
    describe Adapter do
      let(:disk)      { double('Disk') }
      let(:network)   { double('Network') }
      let(:logrotate) { double('Logrotate') }
      let(:password)  { double('Password') }
      subject(:platform)  { Adapter.new(disk, logrotate, password, network) }

      describe 'Method delegation' do
        context 'Disk' do
          it 'delegates mount_persistent_disk to @disk' do
            disk.should_receive(:mount_persistent_disk).with(1)
            platform.mount_persistent_disk(1)
          end
          it 'delegates lookup_disk_by_cid to @disk' do
            disk.should_receive(:lookup_disk_by_cid).with(1)
            platform.lookup_disk_by_cid(1)
          end

          it 'delegates get_data_disk_device_name to @disk' do
            disk.should_receive(:get_data_disk_device_name)
            platform.get_data_disk_device_name
          end
        end

        context 'Logrotate' do
          it 'delegates update_logging to @logrotate#install' do
            logrotate.should_receive(:install).with({})
            platform.update_logging({})
          end
        end

        context 'Network' do
          it 'delegates setup_networking to @network' do
            network.should_receive(:setup_networking)
            platform.setup_networking
          end
        end

        context 'Password' do
          it 'delegates update_passwords to @password#update' do
            settings = {'env' => {'bosh' => {'password' => 'ajdajkda'}}}
            password.should_receive(:update).with(settings)
            platform.update_passwords(settings)
          end
        end
      end
    end
  end
end
