require 'spec_helper'

describe Bosh::WardenCloud::Cloud do
  DEFAULT_HANDLE = 'vm-uuid-1234'
  DEFAULT_STEMCELL_ID = 'stemcell-abcd'
  DEFAULT_AGENT_ID = 'agent-abcd'

  before :each do
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir('warden-cpi-disk')
    @stemcell_path =  Dir.mktmpdir('stemcell-disk')
    @stemcell_root = File.join(@stemcell_path, DEFAULT_STEMCELL_ID)
    Dir.mkdir(@stemcell_root)

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

  def mock_umount_sudos (cmd)
    zero_exit_status = mock('Process::Status', exit_status: 0)
    Bosh::Exec.should_receive(:sh).with(/sudo -n #{cmd}.*/, yield: :on_false).ordered.and_return(zero_exit_status)
  end

  context 'create_vm' do
    before :each do
      @cloud.stub(:uuid).with('vm') { DEFAULT_HANDLE }
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
      @cloud.should_receive(:sudo).exactly(4)
      network_spec = {
        'nic1' => { 'ip' => '1.1.1.1', 'type' => 'static' },
      }
      @cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)
    end

    it 'should raise error for invalid stemcell' do
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
      mock_umount_sudos 'umount'
      mock_umount_sudos 'rm -rf'
      mock_umount_sudos 'rm -rf'
      @cloud.delete_vm(DEFAULT_HANDLE)
    end

    it 'should proceed even delete a vm which not exist' do
      @cloud.stub(:has_vm?).with('vm_not_existed').and_return(false)
      mock_umount_sudos 'rm -rf'
      mock_umount_sudos 'rm -rf'
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
      mock_umount_sudos 'umount'
      mock_umount_sudos 'rm -rf'
      mock_umount_sudos 'rm -rf'
      @cloud.delete_vm(DEFAULT_HANDLE)
    end
  end
end
