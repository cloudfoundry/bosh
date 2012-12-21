require File.expand_path('../../spec_helper',__FILE__)

describe Bosh::WardenCloud::Cloud do
  include Warden::Protocol
  include Bosh::WardenCloud::Helpers
  include Bosh::WardenCloud::Models
  attr_reader :logger

  DEFAULT_HANDLE = "1234"
  DEFAULT_AGENT_ID = "agent-abcd"

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

    #agent settings file
    @agent_settings_file = @cloud.delegate.send(:agent_settings_file)

    #directory for agent setting file
    @dirName = File.dirname(@agent_settings_file)
    unless File.exists? @dirName
      FileUtils.mkdir_p @dirName
      @dir_exists = false
    end

    #create dir for vcap settings if not exist
    File.open(@cloud.delegate.send(:agent_settings_file),"w") do |file|
      file.puts(Yajl::Encoder.encode(@env))
      file.close
    end

    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) {} # no-op
    end

    Warden::Client.any_instance.stub(:call) do |request|
      resp = nil

      if request.instance_of? CopyOutRequest
        FileUtils.copy request.src_path, request.dst_path
        resp = CopyOutResponse.new
      elsif request.instance_of? CopyInRequest
        FileUtils.rm_rf request.dst_path
        env = Yajl::Parser.parse(File.read(request.src_path))

        env["agent_id"].should == DEFAULT_AGENT_ID
        env["networks"]["nic1"]["ip"].should == "1.1.1.1"
        env["networks"]["nic1"]["type"].should == "static"

        request.dst_path.should == "/var/vcap/bosh/settings.json"
        resp = CopyInResponse.new
      else
        raise "not support"
      end

      resp
    end
  end

  after :each do
    unless @dir_exists
      if File.exists? @agent_settings_file
        File.delete @agent_settings_file
      end
      FileUtils.rmdir @dirName
    end
  end

  context do "set_agent_env"
    it "can set agent env" do
      @cloud.delegate.send :set_agent_env, DEFAULT_HANDLE, @env
    end
  end

  context do "get_agent_env"
    it "get agent env" do
      env = @cloud.delegate.send :get_agent_env, DEFAULT_HANDLE

      env["agent_id"].should == DEFAULT_AGENT_ID
      env["networks"]["nic1"]["ip"].should == "1.1.1.1"
      env["networks"]["nic1"]["type"].should == "static"
    end
  end
end
