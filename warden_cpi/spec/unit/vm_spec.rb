require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Cloud do

  include Warden::Protocol
  include Bosh::WardenCloud::Models

  DEFAULT_HANDLE = '1234'
  DEFAULT_STEMCELL_ID = 'stemcell-abcd'
  DEFAULT_AGENT_ID = 'agent-abcd'

  before :all do
    @stemcell_root = Dir.mktmpdir("warden-cpi")
    @stemcell_path = File.join(@stemcell_root, DEFAULT_STEMCELL_ID)
    FileUtils.mkdir_p(@stemcell_path)
  end

  after :all do
    FileUtils.rm_rf(@stemcell_root)
  end

  before :each do
    options = {
      "stemcell" => { "root" => @stemcell_root },
    }
    @cloud = Bosh::Clouds::Provider.create(:warden, options)
  end

  after :each do
    VM.dataset.delete
  end

  context "successful cases" do
    it "can create vm" do
      Warden::Client.any_instance.stub(:call) do |request|
        resp = nil
        if request.instance_of? CreateRequest
          request.network.should == '1.1.1.1'
          request.rootfs.should == File.join(@stemcell_path, 'root')

          resp = CreateResponse.new
          resp.handle = DEFAULT_HANDLE
        elsif request.instance_of? CopyInRequest
          raise 'Container not found' unless request.handle == DEFAULT_HANDLE
          env = Yajl::Parser.parse(File.read(request.src_path))
          env['agent_id'].should == DEFAULT_AGENT_ID
          request.dst_path.should == "/var/vcap/bosh/settings.json"

          resp = CopyInResponse.new
        else
          raise "not supported"
        end

        resp
      end

      network_spec = {
        "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
      }
      id = @cloud.create_vm(DEFAULT_AGENT_ID, DEFAULT_STEMCELL_ID, nil, network_spec)

      # DB Verification
      VM.dataset.all.size.should == 1
      VM[id.to_i].container_id.should == DEFAULT_HANDLE
      VM[id.to_i].id.should == id.to_i
    end

    it "can delete vm" do
      vm = VM.new
      vm.container_id = DEFAULT_HANDLE
      vm.save

      VM.dataset.all.size.should == 1

      Warden::Client.any_instance.stub(:call) do |request|
        resp = nil
        if request.instance_of? DestroyRequest
          request.handle.should == DEFAULT_HANDLE

          resp = DestroyResponse.new
        else
          raise "not supported"
        end

        resp
      end

      @cloud.delete_vm(vm.id.to_s)

      VM.dataset.all.size.should == 0
    end
  end

  context "failed cases" do
    it "should raise error for invalid stemcell" do
      expect {
        @cloud.create_vm('agent_id', 'invalid_stemcell_id', nil, {})
      }.to raise_error
    end

    it "should raise error for more than 1 nics" do
      expect {
        network_spec = {
          "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
          "nic2" => { "type" => "dynamic" },
        }
        @cloud.create_vm('agent_id', 'invalid_stemcell_id', nil, network_spec)
      }.to raise_error
    end

    it "should raise error when trying to delete a vm which doesn't exist" do
      expect {
        @cloud.delete_vm(111) # vm id 11 doesn't exist
      }.to raise_error
    end

  end
end
