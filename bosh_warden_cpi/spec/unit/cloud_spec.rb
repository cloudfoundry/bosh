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
    @warden_client = double(Warden::Client)
    allow(@disk_util).to receive(:stemcell_path).and_return(@stemcell_root)
    allow(Bosh::WardenCloud::DiskUtils).to receive(:new).with(@disk_root, @stemcell_path, 'ext4').and_return(@disk_util)
    allow(Warden::Client).to receive(:new).and_return(@warden_client)

    cloud_options = {
      'plugin' => 'warden',
      'properties' => {
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
    }
    @cloud = Bosh::Clouds::Provider.create(cloud_options, 'fake-director-uuid')

    allow(@warden_client).to receive(:connect) {}
    allow(@warden_client).to receive(:disconnect) {}
  end

  after :each do
    FileUtils.rm_rf @stemcell_path
    FileUtils.rm_rf @disk_root
  end

  context 'initialize' do
    it 'can be created using Bosh::Clouds::Provider' do
      expect(@cloud).to be_an_instance_of(Bosh::Clouds::Warden)
    end
  end

  context 'create_vm' do
    before :each do
      allow(@cloud).to receive(:uuid).with('vm') { DEFAULT_HANDLE }
      Dir.mkdir(@stemcell_root)
      allow(@warden_client).to receive(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::CreateRequest
            expect(req.network).to eq('1.1.1.1')
            expect(req.rootfs).to equal(@stemcell_root)
            expect(req.bind_mounts[0].src_path).to match(/#{@disk_root}\/bind_mount_points/)
            expect(req.bind_mounts[1].src_path).to match(/#{@disk_root}\/ephemeral_mount_point/)
            expect(req.bind_mounts[0].dst_path).to eq('/warden-cpi-dev')
            expect(req.bind_mounts[1].dst_path).to eq('/var/vcap/data')
            expect(req.bind_mounts[0].mode).to eq(Warden::Protocol::CreateRequest::BindMount::Mode::RW)
            expect(req.bind_mounts[1].mode).to eq(Warden::Protocol::CreateRequest::BindMount::Mode::RW)
            res.handle = DEFAULT_HANDLE
          when Warden::Protocol::CopyInRequest
            raise 'Container not found' unless req.handle == DEFAULT_HANDLE
            env = Yajl::Parser.parse(File.read(req.src_path))
            expect(env['agent_id']).to eq(DEFAULT_AGENT_ID)
            expect(env['vm']['name']).not_to be_nil
            expect(env['vm']['id']).not_to be_nil
            expect(env['mbus']).not_to be_nil
            expect(env['ntp']).to be_an_instance_of Array
            expect(env['blobstore']).to be_an_instance_of Hash
          when Warden::Protocol::RunRequest
            # Ignore
          when Warden::Protocol::SpawnRequest
            expect(req.script).to eq('/usr/sbin/runsvdir-start')
            expect(req.privileged).to be true
          when Warden::Protocol::DestroyRequest
            expect(req.handle).to eq(DEFAULT_HANDLE)
            @destroy_called = true
          else
            raise "#{req} not supported"
        end
        res
      end
    end

    it 'can create vm' do
      expect(@cloud).to receive(:sudo).exactly(3)
      network_spec = {
          'nic1' => { 'ip' => '1.1.1.1', 'type' => 'static' },
      }
      @cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)
    end

    it 'should raise error for invalid stemcell' do
      allow(@disk_util).to receive(:stemcell_path).and_return('invalid_dir')
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
      allow(@cloud).to receive(:sudo) {}
      allow(@cloud).to receive(:set_agent_env) { raise FakeError.new }
      network_spec = {
          'nic1' => { 'ip' => '1.1.1.1', 'type' => 'static' },
      }
      begin
        @cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)
      rescue FakeError
      else
        raise 'Expected FakeError'
      end
      expect(@destroy_called).to be true
    end
  end

  context 'delete_vm' do
    it 'can delete vm' do
      allow(@warden_client).to receive(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::DestroyRequest
            expect(req.handle).to eq(DEFAULT_HANDLE)
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
      allow(@cloud).to receive(:has_vm?).with('vm_not_existed').and_return(false)
      mock_sh("rm -rf #{@disk_root}/ephemeral_mount_point/vm_not_existed", true)
      mock_sh("rm -rf #{@disk_root}/bind_mount_points/vm_not_existed", true)
      expect {
        @cloud.delete_vm('vm_not_existed')
      }.to_not raise_error
    end

    it 'can delete a vm with disk attached' do
      allow(@warden_client).to receive(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::DestroyRequest
            expect(req.handle).to eq(DEFAULT_HANDLE)
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
      allow(@warden_client).to receive(:call) do |req|
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
      expect(@cloud.has_vm?(DEFAULT_HANDLE)).to be true
    end

    it 'return false when container not exist' do
      expect(@cloud.has_vm?('vm_not_exist')).to be false
    end
  end

  context 'stemcells' do
    before :each do
      allow(@cloud).to receive(:uuid).with('stemcell') { DEFAULT_STEMCELL_ID }
    end

    it 'invoke disk_utils to create stemcell with uuid' do
      expect(@disk_util).to receive(:stemcell_unpack).with('imgpath', DEFAULT_STEMCELL_ID)
      @cloud.create_stemcell('imgpath', nil)
    end

    it 'invoke disk_utils to delete stemcell with uuid' do
      expect(@disk_util).to receive(:stemcell_delete).with(DEFAULT_STEMCELL_ID)
      @cloud.delete_stemcell(DEFAULT_STEMCELL_ID)
    end
  end

  context 'disk create/delete/attach/detach' do
    before :each do
      allow(@cloud).to receive(:uuid).with('disk') { 'disk-uuid-1234' }
    end

    it 'invoke disk_utils to create disk with uuid' do
      expect(@disk_util).to receive(:create_disk).with('disk-uuid-1234', 1024)
      @cloud.create_disk(1024, nil)
    end

    it 'invoke disk_utils to delete disk with uuid' do
      expect(@disk_util).to receive(:disk_exist?).with('disk-uuid-1234').and_return(true)
      expect(@disk_util).to receive(:delete_disk).with('disk-uuid-1234')
      @cloud.delete_disk('disk-uuid-1234')
    end

    it 'invoke disk_utils to mount disk and setup agent env when attach disk' do
      allow(@cloud).to receive(:get_agent_env) { { 'disks' => { 'persistent' => {} } } }
      expected_env = { 'disks' => { 'persistent' => { 'disk-uuid-1234' => '/warden-cpi-dev/disk-uuid-1234' } } }
      expected_mountpoint = File.join(@disk_root, 'bind_mount_points', 'vm-uuid-1234', 'disk-uuid-1234')
      expect(@disk_util).to receive(:disk_exist?).with('disk-uuid-1234').and_return(true)
      expect(@disk_util).to receive(:mount_disk).with(expected_mountpoint, 'disk-uuid-1234')
      expect(@cloud).to receive(:set_agent_env).with('vm-uuid-1234', expected_env)
      expect(@cloud).to receive(:has_vm?).with('vm-uuid-1234').and_return(true)
      @cloud.attach_disk('vm-uuid-1234', 'disk-uuid-1234')
    end

    it 'invoke disk_utils to umount disk and remove agent env when detach disk' do
      allow(@cloud).to receive(:get_agent_env) { { 'disks' => { 'persistent' => { 'disk-uuid-1234' => '/warden-cpi-dev/disk-uuid-1234' } } } }
      expected_env = { 'disks' => { 'persistent' => { 'disk-uuid-1234' => nil } } }
      expected_mountpoint = File.join(@disk_root, 'bind_mount_points', 'vm-uuid-1234', 'disk-uuid-1234')
      expect(@disk_util).to receive(:disk_exist?).with('disk-uuid-1234').and_return(true)
      expect(@disk_util).to receive(:umount_disk).with(expected_mountpoint)
      expect(@cloud).to receive(:set_agent_env).with('vm-uuid-1234', expected_env)
      expect(@cloud).to receive(:has_vm?).with('vm-uuid-1234').and_return(true)
      @cloud.detach_disk('vm-uuid-1234', 'disk-uuid-1234')
    end
  end

end
