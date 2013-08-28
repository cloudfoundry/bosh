require 'spec_helper'

describe Bosh::WardenCloud::Cloud do
  before :each do
    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) do
        # no-op
      end
    end
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir('warden-cpi-disk')
    @stemcell_root = Dir.mktmpdir('warden-cpi-stemcell')
    options = {
        'disk' => {
            'root' => @disk_root,
            'fs' => 'ext4',
        },
        'stemcell' => {
            'root' => @stemcell_root,
        },
    }
    @cloud = Bosh::Clouds::Provider.create(:warden, options)
  end

  after :each do
    FileUtils.rm_rf @disk_root
    FileUtils.rm_rf @stemcell_root
  end

  context 'create_disk' do
    before :each do
      @cloud.stub(:uuid).with('disk') { 'disk-uuid-1234' }
    end

    it 'can create disk' do
      mock_sh('mkfs -t ext4')
      disk_id  = @cloud.create_disk(1, nil)
      Dir.chdir(@disk_root) do
        image = image_file(disk_id)
        Dir.glob('*').should have(1).items
        Dir.glob('*').should include(image)
        File.stat(image).size.should == 1 << 20
      end
    end

    it 'should raise error if size is 0' do
      expect {
        @cloud.create_disk(0, nil)
      }.to raise_error ArgumentError
    end

    it 'should raise error if size is smaller than 0' do
      expect {
        @cloud.create_disk(-1, nil)
      }.to raise_error ArgumentError
    end

    it 'should clean up when create disk failed' do
      @cloud.stub(:image_path) { '/path/not/exist' }
      expect {
        @cloud.create_disk(1, nil)
      }.to raise_error
      Dir.chdir(@disk_root) do
        Dir.glob('*').should be_empty
      end
    end
  end

  context 'delete_disk' do
    before :each do
      mock_sh('mkfs -t ext4')
      @disk_id = @cloud.create_disk(1, nil)
    end

    it 'can delete disk' do
      Dir.chdir(@disk_root) do
        Dir.glob('*').should have(1).items
        Dir.glob('*').should include(image_file(@disk_id))
        ret = @cloud.delete_disk(@disk_id)
        Dir.glob('*').should be_empty
        ret.should be_nil
      end
    end

    it 'should raise error when trying to delete non-existed disk' do
      expect {
        @cloud.delete_disk('12345')
      }.to raise_error Bosh::Clouds::CloudError
    end

  end

  context 'attach & detach disk' do
    before :each do
      @vm_id = 'vm-uuid-1234'
      @disk_id = 'disk-uuid-1234'
      @attached_disk_id = 'disk_uuid-4321'

      @cloud.stub(:get_agent_env).and_return({ 'disks' => { 'persistent' => {} } })
      @cloud.stub(:set_agent_env) {}

      @cloud.stub(:has_vm?).with(@vm_id).and_return(true)
      @cloud.stub(:has_vm?).with('vm_not_existed').and_return(false)
      @cloud.stub(:has_disk?).with(@disk_id).and_return(true)
      @cloud.stub(:has_disk?).with(@attached_disk_id).and_return(true)
      @cloud.stub(:has_disk?).with('disk_not_existed').and_return(false)

      @cloud.stub(:sleep)

    end

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
