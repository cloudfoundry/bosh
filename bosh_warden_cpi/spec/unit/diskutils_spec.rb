require 'spec_helper'

describe Bosh::WardenCloud::DiskUtils do

  let(:image_path) { asset('stemcell-warden-test.tgz') }
  let(:bad_image_path) { asset('stemcell-not-existed.tgz') }

  before :each do
    @disk_root = Dir.mktmpdir('warden-cpi-path')
    @stemcell_path =  Dir.mktmpdir('stemcell-path')
    @stemcell_root = File.join(@stemcell_path, 'stemcell-uuid')
    @disk_util =  described_class.new(@disk_root, @stemcell_path, 'ext4')
    allow(@disk_util).to receive(:sleep) {}
  end

  after :each do
    FileUtils.rm_rf @disk_root
    FileUtils.rm_rf @stemcell_path
  end

  context 'create_stemcell' do
    it 'will use create stemcell' do
      mock_sh("tar -C #{@stemcell_root} -xzf #{image_path} 2>&1", true)
      @disk_util.stemcell_unpack(image_path, 'stemcell-uuid')
      Dir.chdir(@stemcell_path) do
        expect(Dir.glob('*').size).to eq(1)
        expect(Dir.glob('*')).to include('stemcell-uuid')
      end
    end

    it 'should raise error with bad image path' do
      mock_sh("rm -rf #{@stemcell_root}", true)
      expect {
        @disk_util.stemcell_unpack(bad_image_path, 'stemcell-uuid')
      }.to raise_error
    end
  end

  context 'delete_stemcell' do
    it 'can delete stemcell' do
      Dir.chdir(@stemcell_path) do
        mock_sh("tar -C #{@stemcell_root} -xzf #{image_path} 2>&1", true)
        @disk_util.stemcell_unpack(image_path, 'stemcell-uuid')
        expect(Dir.glob('*').size).to eq(1)
        expect(Dir.glob('*')).to include('stemcell-uuid')
        mock_sh("rm -rf #{@stemcell_root}", true)
        @disk_util.stemcell_delete('stemcell-uuid')
      end
    end
  end

  context 'create_disk' do
    it 'can create disk' do
      mock_sh("/sbin/mkfs -t ext4 -F #{@disk_root}/disk-uuid.img 2>&1")
      @disk_util.create_disk('disk-uuid', 1)
      Dir.chdir(@disk_root) do
        image = 'disk-uuid.img'
        expect(Dir.glob('*').size).to eq(1)
        expect(Dir.glob('*')).to include(image)
        expect(File.stat(image).size).to eq(1 << 20)
      end
      expect(@disk_util.disk_exist?('disk-uuid')).to be true
    end

    it 'should raise error if size is 0' do
      expect {
        @disk_util.create_disk('disk-uuid', 0)
      }.to raise_error ArgumentError
    end

    it 'should raise error if size is smaller than 0' do
      expect {
        @disk_util.create_disk('disk-uuid', -1)
      }.to raise_error ArgumentError
    end

    it 'should clean up when create disk failed' do
      allow(@disk_util).to receive(:image_path) { '/path/not/exist' }
      expect {
        @disk_util.create_disk('disk-uuid', 1)
      }.to raise_error
      Dir.chdir(@disk_root) do
        expect(Dir.glob('*')).to be_empty
      end
    end
  end

  context 'delete_disk' do
    before :each do
      mock_sh("/sbin/mkfs -t ext4 -F #{@disk_root}/disk-uuid.img 2>&1")
      @disk_util.create_disk('disk-uuid', 1)
    end

    it 'can delete disk' do
      Dir.chdir(@disk_root) do
        expect(Dir.glob('*').size).to eq(1)
        expect(Dir.glob('*')).to include('disk-uuid.img')
        @disk_util.delete_disk('disk-uuid')
        expect(Dir.glob('*')).to be_empty
      end
    end
  end

  context 'disk exist' do
    it 'should detect non-existed disk' do
      expect(@disk_util.disk_exist?('12345')).to be false
    end

    it 'should return true for existed disk' do
      @disk_util.create_disk('disk-uuid', 1)
      expect(@disk_util.disk_exist?('disk-uuid')).to be true
    end
  end

  context 'mount & umount disk' do
    before :each do
      @vm_path =  Dir.mktmpdir('warden-cpi-path')
      @vm_id_path = File.join(@vm_path, 'vm-id')
    end

    after :each do
      FileUtils.rm_rf @vm_path
    end

    it 'will invoke sudo mount to attach loop device' do
      mock_sh("mount #{@disk_root}/disk-uuid.img #{@vm_id_path} -o loop", true)
      @disk_util.mount_disk(@vm_id_path, 'disk-uuid')
    end

    it 'will sudo invoke umount to detach loop device' do
      mock_sh("umount #{@vm_id_path}", true)
      allow(@disk_util).to receive(:mount_entry).and_return('nop', nil)
      @disk_util.umount_disk(@vm_id_path)
    end

    it 'will retry umount for detach disk' do
      mock_sh("umount #{@vm_id_path}", true, Bosh::WardenCloud::DiskUtils::UMOUNT_GUARD_RETRIES + 1, false)
      allow(@disk_util).to receive(:mount_entry).and_return('nop')

      expect {
        @disk_util.umount_disk(@vm_id_path)
      }. to raise_error
    end
  end

end
