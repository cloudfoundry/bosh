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
    @stemcell_root = Dir.mktmpdir("warden-cpi")
    @stemcell_path = File.join(@stemcell_root, DEFAULT_STEMCELL_ID)
    FileUtils.mkdir_p(@stemcell_path)
  end

  after(:all) { FileUtils.rm_rf(@stemcell_root) }

  before do
    Bosh::WardenCloud::Models::Disk.dataset.delete
    Bosh::WardenCloud::Models::VM.dataset.delete

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) do
        # no-op
      end
    end
  end

  context "create_vm" do
    before do

      Warden::Client.any_instance.stub(:call) do |request|
        resp = nil
        if request.instance_of? Warden::Protocol::CreateRequest
          request.network.should == "1.1.1.1"
          request.rootfs.should == @stemcell_path

          resp = Warden::Protocol::CreateResponse.new
          resp.handle = DEFAULT_HANDLE
        elsif request.instance_of? Warden::Protocol::CopyInRequest
          raise "Container not found" unless request.handle == DEFAULT_HANDLE
          env = Yajl::Parser.parse(File.read(request.src_path))
          env["agent_id"].should == DEFAULT_AGENT_ID
          env["vm"]["name"].should_not == nil
          env["vm"]["id"].should_not == nil
          env["mbus"].should_not == nil
          env["ntp"].should be_instance_of Array
          env["blobstore"].should be_instance_of Hash

          resp = Warden::Protocol::CopyInResponse.new
        elsif request.instance_of? Warden::Protocol::RunRequest
          resp = Warden::Protocol::RunResponse.new
        elsif request.instance_of? Warden::Protocol::SpawnRequest
          request.script.should == "/usr/sbin/runsvdir-start"
          request.privileged.should == true

          resp = Warden::Protocol::SpawnResponse.new
        elsif request.instance_of? Warden::Protocol::DestroyRequest
          @destroy_called = true
          request.handle.should == DEFAULT_AGENT_ID

          resp = Warden::Protocol::DestroyResponse.new
        else
          raise "not supported"
        end

        resp
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
      cloud.delegate.stub(:sudo) { raise 'error' }

      network_spec = {
        "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
      }
      expect {
        cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)
      }.to raise_error

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

      Warden::Client.any_instance.stub(:call) do |request|
        resp = nil
        if request.instance_of? Warden::Protocol::DestroyRequest
          request.handle.should == DEFAULT_HANDLE

          resp = Warden::Protocol::DestroyResponse.new
        else
          raise "not supported"
        end

        resp
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
