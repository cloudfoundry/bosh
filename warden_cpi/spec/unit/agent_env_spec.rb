require File.expand_path('../../spec_helper',__FILE__)

describe Bosh::WardenCloud::Cloud do
  include Warden::Protocol
  include Bosh::WardenCloud::Helpers
  include Bosh::WardenCloud::Models
  attr_reader :logger

  DEFAULT_HANDLE = "1234"
  DEFAULT_STEMCELL_ID = "stemcell-abcd"
  DEFAULT_AGENT_ID = "agent-abcd"

  before :each do
    @logger = Bosh::Clouds::Config.logger

    @vm=VM.new
    @vm.container_id = DEFAULT_HANDLE
    @vm.save
    network_spec = {
      "nic1" => { "ip" => "1.1.1.1", "type" => "static" },
    }

    options = {
      "stemcell" => { "root" => @stemcell_root },
      "agent" => agent_options,
    }

    @cloud = Bosh::Clouds::Provider.create(:warden, options)

    @env = @cloud.delegate.send :generate_agent_env, @vm, DEFAULT_AGENT_ID, network_spec

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) {} # no-op
    end

    Warden::Client.any_instance.stub(:call) do |request|
      resp = nil

      if request.instance_of? CopyOutRequest
        File.open(request.dst_path,"w") do |file|
          file.puts(Yajl::Encoder.encode(@env))
          file.close
        end
        resp = CopyOutResponse.new
      elsif request.instance_of? CopyInRequest
        env = Yajl::Parser.parse(File.read(request.src_path))
        env["agent_id"].should == DEFAULT_AGENT_ID
        env["networks"]["nic1"]["ip"].should == "1.1.1.1"
        env["networks"]["nic1"]["type"].should == "static"
        env["vm"]["id"].should_not == nil
        env["vm"]["name"].should == DEFAULT_HANDLE
        request.dst_path.should == "/var/vcap/bosh/settings.json"
        resp = CopyInResponse.new
      else
        raise "not support"
      end

      resp
    end
  end

  after :each do
  end

  context do "set_agent_env"
    it "can set agent env" do
      @cloud.delegate.send :set_agent_env, @vm.container_id, @env
    end
  end

  context do "get_agent_env"
    it "get agent env" do
      env = @cloud.delegate.send :get_agent_env, @vm.container_id
      env["agent_id"].should == DEFAULT_AGENT_ID
      env["networks"]["nic1"]["ip"].should == "1.1.1.1"
      env["networks"]["nic1"]["type"].should == "static"
      env["vm"]["id"].should_not == nil
      env["vm"]["name"].should == DEFAULT_HANDLE
    end
  end
end
