require "spec_helper"

describe Bosh::WardenCloud::Cloud do
  DEFAULT_HANDLE = "1234"
  DEFAULT_STEMCELL_ID = "stemcell-abcd"
  DEFAULT_AGENT_ID = "agent-abcd"


  before :each do
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir("warden-cpi-disk")
    @stemcell_path =  Dir.mktmpdir("stemcell-disk")
    @stemcell_root = File.join(@stemcell_path, DEFAULT_STEMCELL_ID)

    Dir.mkdir(@stemcell_root)

    cloud_options = {
        "disk" => {
            "root" => @disk_root,
            "fs" => "ext4",
        },
        "stemcell" => {
            "root" => @stemcell_path,
        },
        "agent" => {
            "mbus" => "nats://nats:nats@192.168.50.4:21084",
            "blobstore" => {
                "provider" => "simple",
                "options" => "option"
            }                          ,
            "ntp" => []
        }
    }
    @cloud = Bosh::Clouds::Provider.create(:warden, cloud_options)

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) do
        # no-op
      end
    end
  end

  before :each do
    Bosh::WardenCloud::Models::Disk.dataset.delete
    Bosh::WardenCloud::Models::VM.dataset.delete
  end

  after(:each) {
    FileUtils.rm_rf @stemcell_path
    FileUtils.rm_rf @disk_root
  }

  def mock_umount_sudos (cmd)
    zero_exit_status = mock("Process::Status", :exit_status => 0)
    Bosh::Exec.should_receive(:sh).with(%r!sudo -n #{cmd}.*!, :yield => :on_false).ordered.and_return(zero_exit_status)
  end

  context "create_vm" do
    before :each do
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response

        case req
        when Warden::Protocol::CreateRequest
          req.network.should == "1.1.1.1"
          req.rootfs.should == @stemcell_root
          req.bind_mounts[0].src_path.should =~ /#{@disk_root}\/bind_mount_points/
          req.bind_mounts[1].src_path.should =~ /#{@disk_root}\/ephemeral_mount_point/
          req.bind_mounts[0].dst_path.should == "/warden-cpi-dev"
          req.bind_mounts[1].dst_path.should == "/var/vcap/data"
          req.bind_mounts[0].mode.should == Warden::Protocol::CreateRequest::BindMount::Mode::RW
          req.bind_mounts[1].mode.should == Warden::Protocol::CreateRequest::BindMount::Mode::RW

          res.handle = DEFAULT_HANDLE

        when Warden::Protocol::CopyInRequest
          raise "Container not found" unless req.handle == DEFAULT_HANDLE
          env = Yajl::Parser.parse(File.read(req.src_path))
          env["agent_id"].should == DEFAULT_AGENT_ID
          env["vm"]["name"].should_not == nil
          env["vm"]["id"].should_not == nil
          env["mbus"].should_not == nil
          env["ntp"].should be_instance_of Array
          env["blobstore"].should be_instance_of Hash

          res = req.create_response

        when Warden::Protocol::RunRequest
          # Ignore

        when Warden::Protocol::SpawnRequest
          req.script.should == "/usr/sbin/runsvdir-start"
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

    it "can create vm" do
      @cloud.delegate.should_receive(:sudo).exactly(4)

      network_spec = {
        "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
      }
      id = @cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)

      # DB Verification
      Bosh::WardenCloud::Models::VM.dataset.all.size.should == 1
      Bosh::WardenCloud::Models::VM[id.to_i].container_id.should == DEFAULT_HANDLE
      Bosh::WardenCloud::Models::VM[id.to_i].id.should == id.to_i
    end

    it "should raise error for invalid stemcell" do
      expect {
        @cloud.create_vm("agent_id", "invalid_stemcell_id", nil, {})
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise error for more than 1 nics" do
      expect {
        network_spec = {
          "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
          "nic2" => { "type" => "dynamic" },
        }
        @cloud.create_vm("agent_id", "invalid_stemcell_id", nil, network_spec)
      }.to raise_error ArgumentError
    end

    it "should clean up DB and warden when an error raised" do
      class FakeError < StandardError; end

      Bosh::WardenCloud::Cloud.any_instance.stub(:sudo) {}
      @cloud.delegate.stub(:set_agent_env) { raise FakeError.new }

      network_spec = {
        "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
      }

      begin
        @cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)
      rescue FakeError
      else
        raise "Expected FakeError"
      end

      Bosh::WardenCloud::Models::VM.dataset.all.size.should == 0

      @destroy_called.should be_true
    end
  end

  context "delete_vm" do
    it "can delete vm" do
      vm = Bosh::WardenCloud::Models::VM.new
      vm.container_id = DEFAULT_HANDLE
      vm.save

      Bosh::WardenCloud::Models::VM.dataset.all.size.should == 1

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

      mock_umount_sudos "umount"
      mock_umount_sudos "rm -rf"
      @cloud.delete_vm(vm.id.to_s)

      Bosh::WardenCloud::Models::VM.dataset.all.size.should == 0
    end

    it "should raise error when trying to delete a vm which doesn't exist" do
      expect {
        @cloud.delete_vm(11) # vm id 11 doesn't exist
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "can delete a vm with disk attached" do
      vm = Bosh::WardenCloud::Models::VM.new
      vm.container_id = DEFAULT_HANDLE
      vm.save

      disk = Bosh::WardenCloud::Models::Disk.new
      disk.vm = vm
      disk.attached = true
      disk.save

      vm.disks.size.should == 1
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
      mock_umount_sudos "umount"
      mock_umount_sudos "rm -rf"
      @cloud.delete_vm(vm.id.to_s)

      disk.refresh
      disk.attached.should == false
      disk.vm.should == nil

    end
  end
end
