require "spec_helper"

describe Bosh::WardenCloud::Cloud do
  DEFAULT_HANDLE = "1234"
  DEFAULT_STEMCELL_ID = "stemcell-abcd"
  DEFAULT_AGENT_ID = "agent-abcd"

  let(:cloud) do
    Bosh::Clouds::Provider.create(:warden,
      "stemcell" => {"root" => @stemcell_root},
      "agent" => agent_options,
    )
  end

  before :all do
    @stemcell_root = cloud_options["stemcell"]["root"]
    @stemcell_path = File.join(@stemcell_root, DEFAULT_STEMCELL_ID)
    FileUtils.mkdir_p(@stemcell_path)
  end

  after(:all) { FileUtils.rm_rf(@stemcell_root) }

  before :each do
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

  context "create_vm" do
    before :each do
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response

        case req
        when Warden::Protocol::CreateRequest
          req.network.should == "1.1.1.1"
          req.rootfs.should == @stemcell_path

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
      cloud.delegate.should_receive(:sudo).once

      network_spec = {
        "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
      }
      id = cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)

      # DB Verification
      Bosh::WardenCloud::Models::VM.dataset.all.size.should == 1
      Bosh::WardenCloud::Models::VM[id.to_i].container_id.should == DEFAULT_HANDLE
      Bosh::WardenCloud::Models::VM[id.to_i].id.should == id.to_i
    end

    it "should raise error for invalid stemcell" do
      expect {
        cloud.create_vm("agent_id", "invalid_stemcell_id", nil, {})
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise error for more than 1 nics" do
      expect {
        network_spec = {
          "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
          "nic2" => { "type" => "dynamic" },
        }
        cloud.create_vm("agent_id", "invalid_stemcell_id", nil, network_spec)
      }.to raise_error ArgumentError
    end

    it "should clean up DB and warden when an error raised" do
      class FakeError < StandardError; end

      @cloud.delegate.stub(:sudo) { raise FakeError.new }

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

        else
          raise "#{req} not supported"
        end

        res
      end

      cloud.delete_vm(vm.id.to_s)

      Bosh::WardenCloud::Models::VM.dataset.all.size.should == 0
    end

    it "should raise error when trying to delete a vm which doesn't exist" do
      expect {
        cloud.delete_vm(11) # vm id 11 doesn't exist
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise error when trying to delete a vm with disk attached" do
      vm = Bosh::WardenCloud::Models::VM.new
      vm.container_id = "1234"
      vm.save

      disk = Bosh::WardenCloud::Models::Disk.new
      disk.vm = vm
      disk.attached = true
      disk.save

      expect {
        cloud.delete_vm(vm.id.to_s)
      }.to raise_error Bosh::Clouds::CloudError, /with disks attached/
    end
  end
end
