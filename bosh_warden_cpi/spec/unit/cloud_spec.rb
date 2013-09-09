require 'spec_helper'

describe Bosh::WardenCloud::Cloud do

  DEFAULT_HANDLE = 'vm-uuid-1234'
  DEFAULT_AGENT_ID = 'agent-abcd'
  DEFAULT_STEMCELL_ID = 'stemcell-uuid'

  before :each do
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir('warden-cpi-disk')
    @stemcell_path =  Dir.mktmpdir('stemcell-disk')
    @stemcell_root = File.join(@stemcell_path, DEFAULT_STEMCELL_ID)
    @disk_util = double('DiskUtils')
    @disk_util.stub(:stemcell_path).and_return(@stemcell_root)
    Bosh::WardenCloud::DiskUtils.stub(:new).with(@disk_root, @stemcell_path, 'ext4').and_return(@disk_util)

    cloud_options = {
        'disk' => {
            'root' => @disk_root,
            'fs' => 'ext4',
        },
        'stemcell' => {
            'root' => @stemcell_path,
        },
        'agent' => {
            'mbus' => 'nats://nats:nats@192.168.50.4:21084',
            'blobstore' => {
                'provider' => 'simple',
                'options' => 'option'
            }                          ,
            'ntp' => []
        }
    }
    @cloud = Bosh::Clouds::Provider.create(:warden, cloud_options)

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) do
        # no-op
      end
    end
  end

  after :each do
    FileUtils.rm_rf @stemcell_path
    FileUtils.rm_rf @disk_root
  end

  context 'initialize' do
    it 'can be created using Bosh::Clouds::Provider' do
      @cloud.should be_an_instance_of(Bosh::Clouds::Warden)
    end
  end

  context 'create_vm' do
    before :each do
      @cloud.stub(:uuid).with('vm') { DEFAULT_HANDLE }
      Dir.mkdir(@stemcell_root)
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::CreateRequest
            req.network.should == '1.1.1.1'
            req.rootfs.should == @stemcell_root
            req.bind_mounts[0].src_path.should =~ /#{@disk_root}\/bind_mount_points/
            req.bind_mounts[1].src_path.should =~ /#{@disk_root}\/ephemeral_mount_point/
            req.bind_mounts[0].dst_path.should == '/warden-cpi-dev'
            req.bind_mounts[1].dst_path.should == '/var/vcap/data'
            req.bind_mounts[0].mode.should == Warden::Protocol::CreateRequest::BindMount::Mode::RW
            req.bind_mounts[1].mode.should == Warden::Protocol::CreateRequest::BindMount::Mode::RW
            res.handle = DEFAULT_HANDLE
          when Warden::Protocol::CopyInRequest
            raise 'Container not found' unless req.handle == DEFAULT_HANDLE
            env = Yajl::Parser.parse(File.read(req.src_path))
            env['agent_id'].should == DEFAULT_AGENT_ID
            env['vm']['name'].should_not == nil
            env['vm']['id'].should_not == nil
            env['mbus'].should_not == nil
            env['ntp'].should be_instance_of Array
            env['blobstore'].should be_instance_of Hash
            res = req.create_response
          when Warden::Protocol::RunRequest
            # Ignore
          when Warden::Protocol::SpawnRequest
            req.script.should == '/usr/sbin/runsvdir-start'
            req.privileged.should == true
          when Warden::Protocol::DestroyRequest
            req.handle.should == DEFAULT_HANDLE
            @destroy_called = true
          else
            raise "#{req} not supported"
        end
        res
      end
    end

    it 'can create vm' do
      @cloud.should_receive(:sudo).exactly(3)
      network_spec = {
          'nic1' => { 'ip' => '1.1.1.1', 'type' => 'static' },
      }
      @cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)
    end

    it 'should raise error for invalid stemcell' do
      @disk_util.stub(:stemcell_path).and_return('invalid_dir')
      expect {
        @cloud.create_vm('agent_id', 'invalid_stemcell_id', nil, {})
      }.to raise_error Bosh::Clouds::CloudError
    end

    it 'should raise error for more than 1 nics' do
      expect {
        network_spec = {
            'nic1' => { 'ip' => '1.1.1.1', 'type' => 'static' },
            'nic2' => { 'type' => 'dynamic' },
        }
        @cloud.create_vm('agent_id', 'invalid_stemcell_id', nil, network_spec)
      }.to raise_error ArgumentError
    end

    it 'should clean up when an error raised' do
      class FakeError < StandardError; end
      Bosh::WardenCloud::Cloud.any_instance.stub(:sudo) {}
      @cloud.stub(:set_agent_env) { raise FakeError.new }
      network_spec = {
          'nic1' => { 'ip' => '1.1.1.1', 'type' => 'static' },
      }
      begin
        @cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)
      rescue FakeError
      else
        raise 'Expected FakeError'
      end
      @destroy_called.should be_true
    end
  end

  context 'delete_vm' do
    it 'can delete vm' do
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::DestroyRequest
            req.handle.should == DEFAULT_HANDLE
          when Warden::Protocol::ListRequest
            res.handles = DEFAULT_HANDLE
          else
            raise "#{req} not supported"
        end
        res
      end
      mock_sh("umount #{@disk_root}/bind_mount_points/#{DEFAULT_HANDLE}", true)
      mock_sh("rm -rf #{@disk_root}/ephemeral_mount_point/#{DEFAULT_HANDLE}", true)
      mock_sh("rm -rf #{@disk_root}/bind_mount_points/#{DEFAULT_HANDLE}", true)
      @cloud.delete_vm(DEFAULT_HANDLE)
    end

    it 'should proceed even delete a vm which not exist' do
      @cloud.stub(:has_vm?).with('vm_not_existed').and_return(false)
      mock_sh("rm -rf #{@disk_root}/ephemeral_mount_point/vm_not_existed", true)
      mock_sh("rm -rf #{@disk_root}/bind_mount_points/vm_not_existed", true)
      expect {
        @cloud.delete_vm('vm_not_existed')
      }.to_not raise_error
    end

    it 'can delete a vm with disk attached' do
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::DestroyRequest
            req.handle.should == DEFAULT_HANDLE
          when Warden::Protocol::ListRequest
            res.handles = DEFAULT_HANDLE
          else
            raise "#{req} not supported"
        end
        res
      end
      mock_sh("umount #{@disk_root}/bind_mount_points/#{DEFAULT_HANDLE}", true)
      mock_sh("rm -rf #{@disk_root}/ephemeral_mount_point/#{DEFAULT_HANDLE}", true)
      mock_sh("rm -rf #{@disk_root}/bind_mount_points/#{DEFAULT_HANDLE}", true)
      @cloud.delete_vm(DEFAULT_HANDLE)
    end
  end

  context 'has_vm' do
    before :each do
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::ListRequest
            res.handles = DEFAULT_HANDLE
          else
            raise "#{req} not supported"
        end
        res
      end
    end

    it 'return true when container exist' do
      @cloud.has_vm?(DEFAULT_HANDLE).should == true
    end

    it 'return false when container not exist' do
      @cloud.has_vm?('vm_not_exist').should == false
    end
  end

  context 'stemcells' do
    before :each do
      @cloud.stub(:uuid).with('stemcell') { DEFAULT_STEMCELL_ID }
    end

    it 'invoke disk_utils to create stemcell with uuid' do
      @disk_util.should_receive(:stemcell_unpack).with('imgpath', DEFAULT_STEMCELL_ID)
      @cloud.create_stemcell('imgpath', nil)
    end

    it 'invoke disk_utils to delete stemcell with uuid' do
      @disk_util.should_receive(:stemcell_delete).with(DEFAULT_STEMCELL_ID)
      @cloud.delete_stemcell(DEFAULT_STEMCELL_ID)
    end
  end

  context 'disk create/delete/attach/detach' do
    before :each do
      @cloud.stub(:uuid).with('disk') { 'disk-uuid-1234' }
    end

    it 'invoke disk_utils to create disk with uuid' do
      @disk_util.should_receive(:create_disk).with('disk-uuid-1234', 1024)
      @cloud.create_disk(1024, nil)
    end

    it 'invoke disk_utils to delete disk with uuid' do
      @disk_util.should_receive(:disk_exist?).with('disk-uuid-1234').and_return(true)
      @disk_util.should_receive(:delete_disk).with('disk-uuid-1234')
      @cloud.delete_disk('disk-uuid-1234')
    end

    it 'invoke disk_utils to mount disk and setup agent env when attach disk' do
      @cloud.stub(:get_agent_env) { { 'disks' => { 'persistent' => {} } } }
      expected_env = { 'disks' => { 'persistent' => { 'disk-uuid-1234' => '/warden-cpi-dev/disk-uuid-1234' } } }
      expected_mountpoint = File.join(@disk_root, 'bind_mount_points', 'vm-uuid-1234', 'disk-uuid-1234')
      @disk_util.should_receive(:disk_exist?).with('disk-uuid-1234').and_return(true)
      @disk_util.should_receive(:mount_disk).with(expected_mountpoint, 'disk-uuid-1234')
      @cloud.should_receive(:set_agent_env).with('vm-uuid-1234', expected_env)
      @cloud.should_receive(:has_vm?).with('vm-uuid-1234').and_return(true)
      @cloud.attach_disk('vm-uuid-1234', 'disk-uuid-1234')
    end

    it 'invoke disk_utils to umount disk and remove agent env when detach disk' do
      @cloud.stub(:get_agent_env) { { 'disks' => { 'persistent' => { 'disk-uuid-1234' => '/warden-cpi-dev/disk-uuid-1234' } } } }
      expected_env = { 'disks' => { 'persistent' => { 'disk-uuid-1234' => nil } } }
      expected_mountpoint = File.join(@disk_root, 'bind_mount_points', 'vm-uuid-1234', 'disk-uuid-1234')
      @disk_util.should_receive(:disk_exist?).with('disk-uuid-1234').and_return(true)
      @disk_util.should_receive(:umount_disk).with(expected_mountpoint)
      @cloud.should_receive(:set_agent_env).with('vm-uuid-1234', expected_env)
      @cloud.should_receive(:has_vm?).with('vm-uuid-1234').and_return(true)
      @cloud.detach_disk('vm-uuid-1234', 'disk-uuid-1234')
    end
  end

end
