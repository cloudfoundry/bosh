require 'spec_helper'

describe Bosh::WardenCloud::Cloud do
  include Bosh::WardenCloud::Helpers
  attr_reader :logger

  before :each do
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir('warden-cpi-disk')

    options = {
      'disk' => {
        'root' => @disk_root,
        'fs' => 'ext4',
      },
      'stemcell' => {
        'root' => @disk_root,
      },
    }
    @cloud = Bosh::Clouds::Provider.create(:warden, options)

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) {} # no-op
    end

    @vm_id = 'vm-uuid-1234'
    @disk_id = 'disk-uuid-1234'
    @attached_disk_id = 'disk_uuid-4321'

    @cloud.stub(:get_agent_env).and_return({ 'disks' => { 'persistent' => {} } })
    @cloud.stub(:set_agent_env) {}
    @cloud.stub(:has_disk?).with('disk_not_existed').and_return(false)
    @cloud.stub(:has_disk?).with(@disk_id).and_return(true)
    @cloud.stub(:has_disk?).with(@attached_disk_id).and_return(true)

    @cloud.stub(:has_vm?).with('vm_not_existed').and_return(false)
    @cloud.stub(:has_vm?).with(@vm_id).and_return(true)
    @cloud.stub(:sleep)
  end

  after do
    FileUtils.rm_rf @disk_root
  end

  context 'attach_disk' do
    it 'can attach disk' do
      mock_sh('mount', true)
      @cloud.attach_disk(@vm_id, @disk_id)
    end

    it 'raise error when trying to attach a disk that not existed' do
      expect {
        @cloud.attach_disk(@vm_id, 'disk_not_existed')
      }.to raise_error Bosh::Clouds::CloudError
    end

    it 'raise error when trying to attach a disk to a non-existed vm' do
      expect {
        @cloud.attach_disk('vm_not_existed', @disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end
  end

  context 'detach_disk' do

    it 'can detach disk' do
      mock_sh('umount', true)
      Bosh::WardenCloud::Cloud.any_instance.stub(:mount_entry).and_return('nop')
      @cloud.detach_disk(@vm_id, @attached_disk_id)
    end

    it 'will retry umount for detach disk' do
      mock_sh('umount', true, Bosh::WardenCloud::Cloud::UMOUNT_GUARD_RETRIES + 1, false)
      Bosh::WardenCloud::Cloud.any_instance.stub(:mount_entry).and_return('nop')
      expect {
        @cloud.detach_disk(@vm_id, @attached_disk_id)
      }. to raise_error
    end

    it 'raise error when trying to detach a disk to a non-existed vm' do
      expect {
        @cloud.detach_disk('vm_not_existed', @attached_disk_id)
      }.to raise_error Bosh::Clouds::CloudError
    end
  end

end
