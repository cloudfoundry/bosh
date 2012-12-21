require File.expand_path('../../spec_helper',__FILE__)

describe Bosh::WardenCloud::Cloud do
  include Warden::Protocol
  include Bosh::WardenCloud::Helpers
  include Bosh::WardenCloud::Models
  attr_reader :logger

  DEFAULT_STEMCELL_ID = "stemcell-abcd"
  DEFAULT_HANDLE = "1234"
  DEFAULT_AGENT_ID = "agent-abcd"

  before :all do
    @stemcell_root = Dir.mktmpdir("warden-cpi")
    @stemcell_path = File.join(@stemcell_root, DEFAULT_STEMCELL_ID)
    FileUtils.mkdir_p(@stemcell_path)
  end

  after :all do
    FileUtils.rm_rf(@stemcell_root)
  end

  before :each do
    @logger = Bosh::Clouds::Config.logger

    network_spec = {
      "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
    }

    @env = {
      "agent_id" => DEFAULT_AGENT_ID,
      "networks" => network_spec,
      "disk" => { "persistent" => {} },
    }

    options = {
      "stemcell" => { "root" => @stemcell_root },
      "agent" => agent_options,
    }

    @cloud = Bosh::Clouds::Provider.create(:warden, options)

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) {} # no-op
    end

    Warden::Client.any_instance.stub(:call) do |request|
      resp = nil

      if request.instance_of? CopyOutRequest
        src_path = File.join(@stemcell_path,request.src_path)
        FileUtils.copy src_path, request.dst_path
        FileUtils.rm_rf src_path
        resp = CopyOutResponse.new
      elsif request.instance_of? CopyInRequest
        @cloud.delegate.should_receive(:sudo).once
        dst_path = File.join(@stemcell_path,request.dst_path)
        FileUtils.mkdir_p File.dirname(dst_path)
        FileUtils.copy request.src_path,dst_path

        resp = CopyInResponse.new
      else
        raise "not support"
      end

      resp
    end
  end

  context do "set and get agent env"
    it "can set agent env" do
      @cloud.delegate.send :set_agent_env, DEFAULT_HANDLE, @env
      env = @cloud.delegate.send :get_agent_env, DEFAULT_HANDLE
      env["agent_id"].should == DEFAULT_AGENT_ID
      env["networks"]["nic1"]["ip"].should == "1.1.1.1"
      env["networks"]["nic1"]["type"].should == "static"
    end
  end
end
